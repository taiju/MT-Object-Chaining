package MT::Object::Chaining::Singleton;

use strict;

sub DESTOROY {};
sub AUTOLOAD {
    my $self = shift;
    my $method = our $AUTOLOAD;
    $method =~ s/.*:://o;
    return $self unless $self->{_obj};
    $self->{_obj}->$method(@_);
    $self;
}

sub tap {
    my ($self, $cb) = @_;
    return $self unless $self->{_obj};
    $cb->($self->{_obj});
    $self;
}

sub _serializer {
    my $method = shift;
    sub { $method->(shift->{_obj}->get_values) };
}

*dump = _serializer(\&Data::Dump::dump);
*yaml = _serializer(\&MT::Util::YAML::Dump);
*json = _serializer(\&MT::Util::to_json);

sub value {
  my ($self, $field) = @_;
  $self->{_obj}->$field;
}

sub new {
    my ( $class, $obj ) = @_;
    bless { _obj => $obj }, $class;
}

1;
