package MT::Object;

use strict;
use warnings;

sub chain {
    my $obj = shift;
    MT::Object::Chaining->_new( $obj );
}

package MT::Object::Chaining;

our $VERSION = '0.1';

use strict;
use warnings;

use MT::Object::Chaining::Singleton;
use Data::Dump;

sub _new {
    my ( $class, $obj_class ) = @_;
    bless { class => $obj_class }, $class;
}

sub new {
    my $self = shift;
    MT::Object::Chaining::Singleton->new($self->{class}->new(@_));
}

sub load {
    my $self = shift;
    my @objs = $self->{class}->load(@_);
    $self->{_objs} = \@objs;
    $self;
}

sub tap {
    my ($self, $cb) = @_;
    return $self unless $self->{_objs};
    $cb->($self->{_objs});
    $self;
}

sub eq {
    my ($self, $index) = @_;
    MT::Object::Chaining::Singleton->new($self->{_objs}->[$index]);
}

sub save {
  my $self = shift;
  $_->save or die $_->errstr for @{$self->{_objs}};
  $self;
}

sub _serializer {
    my $method = shift;
    sub {
      my ($self, $field) = @_;
      $method->([
          map {
              $field ? $_->$field : $_->get_values
          } @{$self->{_objs}}
      ]);
    };
}

*dump = _serializer(\&Data::Dump::dump);
*yaml = _serializer(\&MT::Util::YAML::Dump);
*json = _serializer(\&MT::Util::to_json);

sub each {
    my $self = shift;
    my ($field, $cb) = ref $_[0] eq 'CODE' ? (undef, $_[0]) : @_;
    $field ? $cb->($_) : $cb->(MT::Object::Chaining::Singleton->new($_)) for @{$self->{_objs}};
    $self;
}

sub map {
  my $self = shift;
  my ($field, $cb) = ref $_[0] eq 'CODE' ? (undef, $_[0]) : @_;
  $field ? $_->$field($cb->($_->$field)) : $_->set_values($cb->($_->get_values)) for @{$self->{_objs}};
  $self;
}

sub grep {
  my $self = shift;
  my ($field, $cb) = ref $_[0] eq 'CODE' ? (undef, $_[0]) : @_;
  $self->{_objs} = [grep { $field ? $cb->($_->$field) : $cb->($_->get_values) } @{$self->{_objs}}];
  $self;
}
*filter = \&grep;

sub reduce {
  my $self = shift;
  my ($field, $cb, $init) = ref $_[0] eq 'CODE' ? (undef, @_) : @_;
  my $accum = defined($init) ? $init :
              $field ? (shift @{$self->{_objs}})->$field :
              (shift @{$self->{_objs}})->get_values;
  for my $obj (@{$self->{_objs}}) {
    $accum = $cb->($accum, $field ? $obj->$field : $obj->get_values);
  }
  $accum;
}
*inject = \&reduce;

1;
__END__

=encoding utf-8

=head1 NAME

MT::Object::Chaining - Methods chaining for MT::Object.

=head1 SYNOPSIS

    use MT::Object::Chaining;

    MT->model('entry')->chain                                  # Start method chaining
        ->load({ blog_id => 1, status => MT::Entry::RELEASE }) # Oops, I forgot author_id in terms
        ->grep(author_id => sub { shift == 1 })                # Filtering author_id = 1
        ->map(author_id => sub { 2 })                          # Mapping from author_id = 1 to author_id = 2
        ->save                                                 # Sync db
        ->dump;                                                # Dump objects

=head1 DESCRIPTION

MT::Object::Chaining is extends MT::Object.

It's provide useful methods for methods chaining with MT::Object.

=head1 METHODS

=head2 $model->load(\%terms, \%args)

    MT->model('entry')->chain
      ->load({ status => MT::Entry::RELEASE }, { sort => 'created_by' })
      ->dump;

=head2 $model->new(\%values)

    MT->model('entry')->chain
      ->new
      ->basename('foo')
      ->title('foo')
      ->text('foo!!')
      ->save;

=head2 $model->tap(\&callback)

    MT->model('entry')->chain
      ->load
      ->tap( sub { warn join ',', map { $_->title } @{$_[0]} } );

=head2 $model->eq($index)

    MT->model('entry')->chain->load->eq(0)

=head2 $model->save

    MT->model('entry')->chain->load->map(author_id => sub { 1 })->save;

=head2 $model->dump($field)

    MT->model('entry')->chain->load->dump;
    MT->model('entry')->chain->load->dump('title');

=head2 $model->yaml($field)

    MT->model('entry')->chain->load->yaml;
    MT->model('entry')->chain->load->yaml('title');

=head2 $model->json($field)

    MT->model('entry')->chain->load->json;
    MT->model('entry')->chain->load->json('title');

=head2 $model->each($field, \&callback)

    MT->model('entry')->chain->load->each(title => sub { print shift . "\n" });
    MT->model('entry')->chain->load->each(sub { print $_->id . ': ' . $_->title . "\n" });

=head2 $model->map($field, \&callback)

    MT->model('entry')->chain->load->map(author_id => sub { 1 })->save
    MT->model('entry')->chain->load->map(sub { $_->{author_id} = 1; $_ })->save

=head2 $model->grep($field, \&callback)

    MT->model('entry')->chain->load->grep(status => sub { shift == 2 })
    MT->model('entry')->chain->load->map(sub { $_->{status} == 2 })->save

=head2 $model->filter($field, \&callback)

Alias for grep

=head2 $model->reduce($field, \&callback, $initialize)

    MT->model('entry')->chain->load->reduce(title => sub { shift . ', ' . shift });
    MT->model('entry')->chain->load->reduce(sub { my ($x, $y) = @_; (ref $x eq 'HASH' ? $x->{title} : $x) . ', ' . $y->{title} });

=head2 $model->inject($field, \&callback, $initialize)

Alias for reduce.

=head2 $singleton->tap(\&callback)

    MT->model('entry')->chain->load->eq(0)->tap(sub { print MT::Util::YAML::Dump(shift->to_hash) });

=head2 $singleton->dump

=head2 $singleton->yaml

=head2 $singleton->json

    MT->model('entry')->chain->load->eq(0)->dump;
    MT->model('entry')->chain->load->eq(0)->yaml;
    MT->model('entry')->chain->load->eq(0)->json;

=head2 $singleton->value($field)

    MT->model('entry')->chain->load->eq(0)->value('title');

=head2 $singleton->$column

All of MT::Object methods return MT::Object::Chaining::Singleton instance.

=head1 TOOLS

tools/chain is useful command line tools for MT::Object::Chaining.

    $ cd /path/to/mt && ./tools/chain -m entry -e '$model->load->json'

=head1 LICENSE

Copyright (C) HIGASHI Taiju.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

HIGASHI Taiju E<lt>higashi@taiju.infoE<gt>

=cut
