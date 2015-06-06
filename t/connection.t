use Mojo::Base -strict;
use Test::More;
use Convos::Core;

my $core       = Convos::Core->new;
my $user       = $core->user('test@example.com', {});
my $connection = $user->connection(IRC => 'whatever');

isa_ok($connection->room('#foo'), 'Convos::Core::Room');
ok !$connection->{room}{'#foo'}, 'no room on get';
my $room = $connection->room('#foo' => {});
is $room->_path, 'test@example.com/IRC-whatever/#foo', 'room->_path';
is $room->n_users, 0, 'room->n_users';
ok $connection->{room}{'#foo'}, 'room on create/update';

$connection = Convos::Core::Connection->new;
for my $method (qw( connect join_room room_list send topic)) {
  my $err;
  eval {
    $connection->$method(sub { $err = $_[1] });
  };
  is $err, qq(Method "$method" not implemented.), $method;
}

done_testing;
