use lib '.';
use t::Helper;
use Convos::Plugin::Bot::Action::Hailo;

plan skip_all => 'TEST_BOT=1' unless $ENV{TEST_BOT};

$ENV{CONVOS_BOT_ALLOW_STANDALONE} = 1;
$ENV{CONVOS_BOT_EMAIL} ||= 'bot@convos.chat';

my $t     = t::Helper->t;
my $hailo = Convos::Plugin::Bot::Action::Hailo->new;

$hailo->register($t->app->bot, {});

$hailo->emit(message => {message => '!'});
$hailo->emit(message => {message => ''});
$hailo->emit(message => {message => 'Hi'});
$hailo->emit(message => {message => 'Superman rocks!'});
is $hailo->hailo->stats, 2, 'learnt two things';

is $hailo->reply({message => 'Superman?'}), undef, 'reply is disabled';

my $config = $hailo->config->data->{action}{'Convos::Plugin::Bot::Action::Hailo'} = {};
$config->{free_speak_ratio} = 1;
is $hailo->reply({message => 'Superman?'}), 'Superman rocks!', 'free_speak_ratio';

$config->{free_speak_ratio}   = 0;
$config->{reply_on_highlight} = 1;
is $hailo->reply({message => 'Superman?'}), undef, 'reply_on_highlight, but not highlighted';
is $hailo->reply({message => 'bot: Superman?', highlight => 1}), 'Superman rocks!',
  'reply_on_highlight and highlighted';

done_testing;
