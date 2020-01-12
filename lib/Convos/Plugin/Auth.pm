package Convos::Plugin::Auth;
use Mojo::Base 'Mojolicious::Plugin';

use Mojo::JSON qw(encode_json decode_json false true);
use Mojo::Util qw(b64_decode b64_encode hmac_sha1_sum);

use constant TOKEN_EXPIRE => 24 * 7;

sub register {
  my ($self, $app, $config) = @_;

  $app->helper('auth.generate_token' => \&_generate_token);
  $app->helper('auth.login_p'        => \&_login_p);
  $app->helper('auth.logout_p'       => \&_logout_p);
  $app->helper('auth.parse_token'    => \&_parse_token);
  $app->helper('auth.register_p'     => \&_register_p);
}

sub _generate_token {
  my ($c, $params, $secret) = @_;
  my $payload = b64_encode(encode_json({exp => time + TOKEN_EXPIRE, %$params}), '');
  return join '!', $payload, hmac_sha1_sum $payload, $secret || $c->app->secrets->[0];
}

sub _login_p {
  my ($c, $args) = @_;
  my $user = $c->app->core->get_user($args);
  return Mojo::Promise->resolve($user) if $user and $user->validate_password($args->{password});
  return Mojo::Promise->reject('Invalid email or password.');
}

sub _logout_p {
  my ($c, $args) = @_;
  return Mojo::Promise->resolve;
}

sub _parse_token {
  my ($c, $token, $secrets) = @_;
  my ($payload, $sum) = split '!', $token // '';
  return {errors => [{message => 'Invalid input.'}]} unless $payload and $sum;

  $payload = decode_json $payload;
  return {errors => [{message => 'Expired.'}]} if !$payload->{exp} or $payload->{exp} < time;

  for my $secret ($secrets ? (@$secrets) : @{$c->app->secrets}) {
    return $payload if $sum eq hmac_sha1_sum $payload, $secret;
  }

  return {errors => [{message => 'Invalid input.'}]};
}

sub _register_p {
  my ($c, $args) = @_;
  my $core = $c->app->core;

  return Mojo::Promise->reject('Email is taken.') if $core->get_user($args);
  return $core->user($args)->set_password($args->{password})->save_p;
}

1;

=encoding utf8

=head1 NAME

Convos::Plugin::Auth - Convos plugin for handling authentication

=head1 DESCRIPTION

L<Convos::Plugin::Auth> is used to register, login and logout a user. This
plugin is always loaded by L<Convos>, but you can override the L</HELPERS>
with a custom auth plugin if you like.

Note that this plugin is currently EXPERIMENTAL. Let us know if you are/have
created a custom plugin.

=head1 HELPERS

=head2 auth.login_p

  $p = $c->auth->login_p(\%credentials)->then(sub { my $user = shift });

Used to login a user. C<%credentials> normally contains an C<email> and
C<password>.

=head2 auth.logout

  $p = $c->auth->logout_p({});

Used to log out a user.

=head2 auth.register

  $p = $c->auth->register(\%credentials)->then(sub { my $user = shift });

Used to register a user. C<%credentials> normally contains an C<email> and
C<password>.

=head1 METHODS

=head2 register

  $auth->register($app, \%config);

=head1 SEE ALSO

L<Convos>

=cut
