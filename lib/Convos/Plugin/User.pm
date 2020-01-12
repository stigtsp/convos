package Convos::Plugin::User;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::DOM;
use Mojo::JSON qw(false true);
use Mojo::Util qw(hmac_sha1_sum trim);
use Socket qw(inet_aton AF_INET);

use constant INVITE_LINK_VALID_FOR => $ENV{CONVOS_INVITE_LINK_VALID_FOR} || 24;

sub register {
  my ($self, $app, $config) = @_;

  $self->helper('rpc.delete_user'    => \&_rpc_delete);
  $self->helper('rpc.get_user'       => \&_rpc_get);
  $self->helper('rpc.login_user'     => \&_rpc_login);
  $self->helper('rpc.logout_user'    => \&_rpc_logout);
  $self->helper('rpc.register_user'  => \&_rpc_register);
  $self->helper('rpc.update_user'    => \&_rpc_update);
  $self->helper('rpc.validate_token' => \&_rpc_validate_token);
}

sub _is_valid_invite_token {
  my ($c, $user, $params) = @_;

  $params->{password} = $user ? $user->password : $c->settings('local_secret');
  for my $secret (@{$c->app->secrets}) {
    my $generated = _add_invite_token_to_params({%$params}, $secret);
    return 1 if $generated->{token} eq $params->{token};
  }

  return 0;
}

sub _normalize {
  return {} unless my $params = shift;

  for my $k (qw(email password)) {
    next unless defined $params->{$k};
    $params->{$k} = trim $params->{$k};
    delete $params->{$k} unless length $params->{$k};
  }

  $params->{highlight_keywords} = [grep {/\w/} map { trim $_ } @{$params->{highlight_keywords}}]
    if $params->{highlight_keywords};

  return $params;
}

# $params = {}
sub _rpc_delete {
  my ($c, $params) = @_;

  return $c->rpc->reply($params, 'not_logged_in') unless my $user = $c->backend->user;
  return $c->rpc->reply($params, 'You are the only user left.') if @{$c->app->core->users} <= 1;
  return $c->app->core->backend->delete_object_p($user)->then(sub {
    $c->rpc->reply($params, {message => 'You have been erased.', token => undef});
  });
}

# $params = {email => '...', exp => 24}
sub _rpc_generate_invite_link {
  my ($c, $params) = @_;

  return $c->rpc->reply($params, 'You are not an admin.')
    unless my $admin_from = $c->user_has_admin_rights;

  my $exp        = time + ($params->{exp} || INVITE_LINK_VALID_FOR) * 3600;
  my $exp_dt     = Mojo::Date->new($exp)->to_datetime;
  my $user       = $c->app->core->get_user($params->{email});
  my $secret     = $user ? $user->password : $c->settings('local_secret');
  my $invitation = $c->auth->generate_token({email => $params->{email}, exp => $exp}, $secret);

  $invitation->{url} = $c->url_for('register');
  $invitation->{url}->query->param($_ => $invitation->{$_}) for qw(email token);
  $invitation->{url} = $invitation->{url}->to_abs->to_string;

  return $c->rpc->reply($params,
    {existing => $user ? true : false, expires => $exp_dt, url => $invitation->{url}});
}

# $params = {}
sub _rpc_get {
  my ($c, $params) = @_;
  return $c->rpc->reply($params, 'not_logged_in') unless my $user = $c->backend->user;
  return $user->get_p($c->req->url->query->to_hash)->then(sub { $c->rpc->reply(shift) });
}

# $params = {email => '...', password => '...'}
# $params = {token => '...'}
sub _rpc_login {
  my ($c, $params) = (shift, _normalize(shift));

  if ($params->{token}) {
    my $token = $c->auth->parse_token($params->{token});
    my $user  = $token->{email} && $c->app->core->get_user($token->{email});
    my $res   = $user ? $user->TO_JSON : $token;
    $res->{token} = $user ? $c->auth->generate_token({email => $user->email}) : undef;
    return $c->rpc->reply($params => $res);
  }

  return $c->auth->login_p($params)->then(sub {
    my $user = shift;
    my $res  = $user->TO_JSON;
    $res->{token} = $c->auth->generate_token({email => $user->email});
    $c->rpc->reply($params => $res);
  });
}

# $params = {}
sub _rpc_logout {
  my ($c, $params) = @_;

  return $c->auth->logout_p($params)
    ->then(sub { $c->rpc->reply({message => 'Logged out.', token => undef}) });
}

# $params = {email => '...', password => '...'}
# $params = {email => '...', password => '...', token => '...'}
sub _rpc_register {
  my ($c, $params) = (shift, _normalize(shift));
  my $user = $c->app->core->get_user($params->{email});

  # Only the first user can join without invite link
  if ($c->app->core->n_users) {

    # Validate input
    return $c->rpc->reply($params, 'Convos registration is not open to public.')
      if !$params->{token} and !$c->settings('open_to_public');

    # TODO: Add test
    return $c->rpc->reply($params, 'Email is taken.') if !$params->{token} and $user;

    my $token = $params->{token} && $c->auth->parse_token($params->{token});
    return $c->rpc->reply($params,
      'Invalid token. You have to ask your Convos admin for a new link.')
      if $token and $token->{errors};

    # Update existing user
    return _update_user($c, $user, $params) if $user;
  }

  # Register new user
  return $c->auth->register_p($params)->then(sub {
    $user = shift;
    $user->role(give => 'admin') if $c->app->core->n_users == 1;
    return $c->backend->connection_create_p(Mojo::URL->new($c->settings('default_connection')));
  })->then(sub {
    my $connection = shift;
    my $res        = $user->TO_JSON;
    $res->{token} = $c->auth->generate_token({email => $user->email});
    $c->app->core->connect($connection);
    $c->rpc->reply($params, $res);
  });
}

# $params = {highlight_keywords => ['...', ...], password => '...'}
sub _rpc_update {
  my ($c, $params) = (shift, _normalize(shift));

  return $c->rpc->reply($params, 'not_logged_in') unless my $user = $c->backend->user;
  return $c->rpc->reply($params, $user) unless %$params;
  return _update_user($c, $user, $params);
}

sub _rpc_validate_token {
  my ($c, $params) = @_;

  return $c->rpc->reply($params, 'Invalid input.')
    unless $params->{token}
    and $params->{email}
    and $params->{exp};
  return $c->rpc->reply($params, 'Expired.') if $params->{exp} =~ m!\D! or $params->{exp} < time;

  my $user = $c->app->core->get_user($params->{email});
  return $c->stash(status => 400) unless _is_valid_invite_token($c, $user, $params);
}

sub _update_user {
  my ($c, $user, $params) = @_;

  $user->highlight_keywords($params->{highlight_keywords}) if $params->{highlight_keywords};
  $user->set_password($params->{password})                 if $params->{password};
  return $user->save_p->then(sub {
    my $res = $user->TO_JSON;
    $res->{token} = $c->auth->generate_token({email => $user->email});
    $c->rpc->reply($params, $res);
  });
}

1;

=encoding utf8

=head1 NAME

Convos::Controller::User - Convos user actions

=head1 DESCRIPTION

L<Convos::Controller::User> is a L<Mojolicious::Controller> with
user related actions.

=head1 METHODS

=head2 delete

See L<Convos::Manual::API/deleteUser>.

=head2 docs

Will render docs built with C<pnpm run generate-docs>.

=head2 generate_invite_link

See L<Convos::Manual::API/inviteUser>.

=head2 get

See L<Convos::Manual::API/getUser>.

=head2 login

See L<Convos::Manual::API/loginUser>.

=head2 logout

See L<Convos::Manual::API/logoutUser>.

=head2 redirect_if_not_logged_in

Used in a L<Mojolicious::Routes::Route/under> to respond with 302, if the user
does not have a valid session cookie.

=head2 register

See L<Convos::Manual::API/registerUser>.

=head2 register_html

Will handle the "uri" that can hold "irc://...." URLs.

=head2 update

See L<Convos::Manual::API/updateUser>.

=head1 SEE ALSO

L<Convos>.

=cut
