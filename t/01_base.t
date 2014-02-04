use strict;
use warnings;

use lib qw(lib extlib t/lib);

use Test::More;
use MT::Test qw(:db :data);
use YAML::Syck;
use JSON;

use MT::Object::Chaining;

isa_ok(MT->model('entry')->chain, 'MT::Object::Chaining');
isa_ok(MT->model('entry')->chain->new, 'MT::Object::Chaining::Singleton');
isa_ok(MT->model('entry')->chain->load, 'MT::Object::Chaining');

my $entry = MT->model('entry')->load;
my $singleton = MT->model('entry')->chain->load->eq(0);
isa_ok($singleton, 'MT::Object::Chaining::Singleton');
is $singleton->value('title'), $entry->title; 

is $singleton->dump, Data::Dump::dump($entry->get_values);
is_deeply YAML::Syck::Load($singleton->yaml), $entry->get_values;
is_deeply JSON::from_json($singleton->json), $entry->get_values;
my $obj;
$singleton->tap(sub { $obj = shift });
is_deeply($obj, $entry);

my @entries = MT->model('entry')->load;
my $chained = MT->model('entry')->chain->load;

is $chained->dump, Data::Dump::dump([map { $_->get_values } @entries]);
is $chained->dump('title'), Data::Dump::dump([map { $_->title } @entries]);
is_deeply YAML::Syck::Load($chained->yaml), [map { $_->get_values } @entries];
is_deeply YAML::Syck::Load($chained->yaml('title')), [map { $_->title } @entries];
is_deeply JSON::from_json($chained->json), [map { $_->get_values } @entries];
is_deeply JSON::from_json($chained->json('title')), [map { $_->title } @entries];

is_deeply JSON::from_json($chained->map(title => sub { 'test' })->json), [map { $_->title('test'); $_->get_values } @entries];
$chained = MT->model('entry')->chain->load;
@entries = MT->model('entry')->load;

is_deeply JSON::from_json($chained->map(sub { $_->title('test'); $_->get_values })->json), [map { $_->title('test'); $_->get_values } @entries];
$chained = MT->model('entry')->chain->load;
@entries = MT->model('entry')->load;

my @filtered_entries = MT->model('entry')->load({author_id => 2});
is_deeply JSON::from_json($chained->grep(author_id => sub { shift == 2 })->json), [map { $_->get_values } @filtered_entries];
$chained = MT->model('entry')->chain->load;
is_deeply JSON::from_json($chained->grep(sub { shift->{author_id} == 2 })->json), [map { $_->get_values } @filtered_entries];
$chained = MT->model('entry')->chain->load;
is_deeply JSON::from_json($chained->filter(author_id => sub { shift == 2 })->json), [map { $_->get_values } @filtered_entries];
$chained = MT->model('entry')->chain->load;

is $chained->reduce(title => sub { shift . "," . shift }), join ',', map { $_->title } @entries;
is $chained->reduce(sub { my ($x, $y) = @_; (ref $x eq 'HASH' ? $x->{title} : $x) . ',' . $y->{title} }), join ',', map { $_->title } @entries;
is $chained->inject(title => sub { shift . "," . shift }), join ',', map { $_->title } @entries;

my $objs = [];
$chained->tap(sub { $objs = shift });
is_deeply [map { $_->get_values } @$objs], [map { $_->get_values } @entries];

my $titles = [];
$chained->each(title => sub { push @$titles, shift });
is_deeply $titles, [map { $_->title } @entries];

$titles = [];
$chained->each(sub { push @$titles, shift->{title} });
is_deeply $titles, [map { $_->title } @entries];

my @old_entries = MT->model('entry')->load;
$chained->map(author_id => sub { 3 })->save;
my @new_entries = MT->model('entry')->load;

isnt((join ',', map { $_->author_id } @old_entries), (join ',', map { $_->author_id } @new_entries));

@old_entries = MT->model('entry')->load;
$chained->map(author_id => sub { 2 })->sync;
@new_entries = MT->model('entry')->load;

isnt((join ',', map { $_->author_id } @old_entries), (join ',', map { $_->author_id } @new_entries));

done_testing;
