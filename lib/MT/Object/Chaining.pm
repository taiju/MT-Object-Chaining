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
  my ($self, $field, $cb) = @_;
  $_->$field($cb->($_->$field)) for @{$self->{_objs}};
  $self;
}

sub grep {
  my ($self, $field, $cb) = @_;
  $self->{_objs} = [grep { $cb->($_->$field) } @{$self->{_objs}}];
  $self;
}
*filter = \&grep;

sub reduce {
  my ($self, $field, $cb, $init) = @_;
  my $accum = defined($init) ? $init : (shift @{$self->{_objs}})->$field;
  for my $obj (@{$self->{_objs}}) {
    $accum = $cb->($accum, $obj->$field);
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
        ->grep(author_id => sub { shift eq 1 })                # Filtering author_id = 1
        ->map(author_id => sub { 2 })                          # Mapping from author_id = 1 to author_id = 2
        ->save                                                 # Sync db
        ->dump;                                                # Dump objects

=head1 DESCRIPTION

MT::Object::Chaining is extends MT::Object.

It's provide useful methods for methods chaining with MT::Object.

=head1 METHODS

=head2 load(\%terms, \%args)

    MT->model('entry')->chain
      ->load({ status => MT::Entry::RELEASE }, { sort => 'created_by' })
      ->dump;

Return MT::Object::Chaining::Singleton instance.

=head2 new(\%values)

    MT->model('entry')->chain
      ->new
      ->basename('foo')
      ->title('foo')
      ->text('foo!!')
      ->save;

=head2 tap(\&callback)

    MT->model('entry')->chain
      ->load
      ->tap( sub { warn join ',', map { $_->title } @{$_[0]} } );

=head2 eq($index)

    MT->model('entry')->chain->load->eq(0)

=head2 save

    MT->model('entry')->chain->load->map(author_id => sub { 1 })->save;

=head2 dump($field)

    MT->model('entry')->chain->load->dump;
    MT->model('entry')->chain->load->dump('title');

=head2 yaml($field)

    MT->model('entry')->chain->load->yaml;
    MT->model('entry')->chain->load->yaml('title');

=head2 json($field)

    MT->model('entry')->chain->load->json;
    MT->model('entry')->chain->load->json('title');

=head2 each($field, \&callback)

    MT->model('entry')->chain->load->each(title => sub { print shift . "\n" });
    MT->model('entry')->chain->load->each(sub { print $_->id . ': ' . $_->title . "\n" });

=head2 map($field, \&callback) 

    MT->model('entry')->chain->load->map(author_id => sub { 1 })->save

=head2 grep($field, \&callback)

    MT->model('entry')->chain->load->grep(status => 2)

=head2 filter($field, \&callback)

Alias grep

=head2 reduce($field, \&callback, $initialize)

    MT->model('entry')->chain->load->reduce(title => sub { shift . ', ' . shift });

=head2 inject($field, \&callback, $initialize)

Alias reduce.

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
