package Tie::RangeHash;

require 5.005_62;
use strict;
use warnings;

require Exporter;
use AutoLoader qw(AUTOLOAD);

require Carp;

our @ISA = qw(Exporter Tie::Hash);

# our %EXPORT_TAGS = ( 'all' => [ qw(
# ) ] );

# our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
# our @EXPORT = qw(
# );

our $VERSION = '0.20';

sub TYPE_NUMBER { return 1; }            # some internal constants
sub TYPE_STRING { return 2; }

our $SEPARATOR = ",";

sub _new_node
  {
    my ($self, $lower_bound, $upper_bound, $value) = @_;

    my $node = {
      KEY_LOW    => $lower_bound,         #
      KEY_HIGH   => $upper_bound,         #
      VALUE      => $value,               #
      NODE_LEFT  => undef,                #
      NODE_RIGHT => undef,                #
      CNT_LEFT   => 0,
      CNT_RIGHT  => 0,
    };

    return $node;
  }

sub _cmp                                  # wrapper for comparison routine
  {
    my ($self, $a, $b) = @_;
    return &{$self->{COMPARE}}($a, $b);
  }

sub _count_left
  {
    my ($node) = @_;
    no warnings;
    if ($node->{NODE_LEFT})
      {
	$node->{CNT_LEFT} = 1 + $node->{NODE_LEFT}->{CNT_LEFT} +
	  $node->{NODE_LEFT}->{CNT_RIGHT};
      }
    else
      {
	$node->{CNT_LEFT} = 0;
      }
  }

sub _count_right
  {
    my ($node) = @_;
    no warnings;
    if ($node->{NODE_RIGHT})
      {
	$node->{CNT_RIGHT} = 1 + $node->{NODE_RIGHT}->{CNT_LEFT} +
	  $node->{NODE_RIGHT}->{CNT_RIGHT};
      }
    else
      {
	$node->{CNT_RIGHT} = 0;
      }
  }

sub _add_node
  {
    my ($self, $root, $node) = @_;

    unless ($root)
      {
	return $node;
      }

    my ($cmp_low, $cmp_high) =
      (
       _cmp($self, $node->{KEY_LOW},  $root->{KEY_LOW}),
       _cmp($self, $node->{KEY_HIGH}, $root->{KEY_HIGH})
      );

    if ($cmp_low < 0)
      {
	$root->{NODE_LEFT} = _add_node( $self, $root->{NODE_LEFT}, $node );
	_count_left($root);
      }
    elsif ($cmp_high > 0)
      {
	$root->{NODE_RIGHT}  = _add_node( $self, $root->{NODE_RIGHT}, $node );
	_count_right($root);
      }
    else
      {
	Carp::croak ("Overlapping range: cannot add new node as \`",
		     join($SEPARATOR, $node->{KEY_LOW}, $node->{KEY_HIGH}),
		     "\' because there exists a node with \`",
		     join($SEPARATOR, $root->{KEY_LOW}, $root->{KEY_HIGH}),
		     "\'"
		     );
      }

    my $balance = $root->{CNT_RIGHT} - $root->{CNT_LEFT};

    if ($balance > 1)
      {
	my $right = $root->{NODE_RIGHT};

	$root->{NODE_RIGHT} = $right->{NODE_LEFT};
	$right->{NODE_LEFT} = $root;

	_count_right($root);
	_count_left($right);

	return $right;
      }
    elsif ($balance < -1)
      {
	my $left = $root->{NODE_LEFT};

	$root->{NODE_LEFT} = $left->{NODE_RIGHT};
	$left->{NODE_RIGHT} = $root;

	_count_left($root);
	_count_right($left);
	
	return $left;
      }

    return $root;
  }

sub _add_new_node
  {
    my ($self, $lower_bound, $upper_bound, $value) = @_;

#     if (_cmp($self, $lower_bound, $upper_bound) > 0)
#       {
# 	Carp::carp "Warning: lower and upper bounds reversed";
# 	($lower_bound, $upper_bound) = ($upper_bound, $lower_bound);	
#       }

    $self->{ROOT} = _add_node( $self, $self->{ROOT},
        _new_node($self, $lower_bound, $upper_bound, $value)
    );
  }


sub _find_node
  {
    my ($self, $root, $key) = @_;

    unless ($root) { return; }

    my ($cmp_low, $cmp_high) =
      (
       _cmp($self, $key,  $root->{KEY_LOW}),
       _cmp($self, $key, $root->{KEY_HIGH})
      );

    if ($cmp_low<0)
      {
	return _find_node($self, $root->{NODE_LEFT}, $key);
      }
    elsif ($cmp_high>0)
      {
	return _find_node($self, $root->{NODE_RIGHT}, $key);
      }
    else
      {
	return $root->{VALUE};
      }

  }

sub _join_bounds                        # generate a key from bounds
  {
    my ($self, $lower, $upper) = @_;
    return join($SEPARATOR, $lower, $upper);
  }

sub _split_bounds                      # generate bounds from a key
  {
    my ($self, $key) = @_;
    my ($lower, $upper, $extra) = split $self->{SEPARATOR}, $key;

    if (defined($extra))
      {
	Carp::carp "Multiple separators in \`$key\' will be ignored";
      }

    unless (defined($upper))
      {
	$upper = $lower;
      }

    if ($self->_cmp($lower, $upper) > 0) {  # make sure lower < upper
      Carp::carp "Warning: lower and upper bounds reversed";
      ($lower, $upper) = ($upper, $lower);
    }

    return ($lower, $upper);
  }

sub TIEHASH
  {
    my ($class, $attributes) = @_;
    my $self = {
      ROOT      => undef,                               # root node
      SEPARATOR => $attributes->{Separator}  || qr/$SEPARATOR/, # default Regexp
      TYPE      => $attributes->{Type}  || TYPE_STRING, # comparison type
      COMPARE   => $attributes->{Comparison},           # compairson subroutine
    };

    if (ref($self->{SEPARATOR}) ne "Regexp")
      {
	Carp::croak
	  "\`Separator\' attribute must be a compiled regular expression";
      }

    unless (defined($self->{COMPARE}))
      {
	if ($self->{TYPE} == TYPE_NUMBER)
	  {
	    $self->{COMPARE} = sub { my ($A, $B) = @_; return $A <=> $B; };
	  }
	elsif ($self->{TYPE} == TYPE_STRING)
	  {
	    $self->{COMPARE} = sub { my ($A, $B) = @_; return $A cmp $B; };
	  }
	else
	  {
	    Carp::croak "Unknown comparison Type";
	  }
      }

    bless $self, $class;
  }

sub FETCH
  {
    my ($self, $key) = @_;
    return $self->_find_node($self->{ROOT}, $key);
  }

sub STORE
  {
    my ($self, $key, $value) = @_;
    my ($lower, $upper) = $self->_split_bounds($key);
    $self->_add_new_node($lower, $upper, $value);
  }

sub CLEAR
  {
    my ($self) = @_;
    $self->{ROOT} = undef;
  }

1;
__END__

=head1 NAME

Tie::RangeHash - Implements "Range Hashes" in Perl

=head1 SYNOPSIS

  use Tie::RangeHash;

  tie %hash, Tie::RangeHash;

  $hash{'A,C'} = 1;
  $hash{'D,F'} = 2;
  $hash{'G,K'} = 3;

  print $hash{'E'}; # outputs '2'

=head1 DESCRIPTION

This module allows hashes to have key ranges based on lower and upper bounds.

For instance, you could pass date ranges to the hash and then query it with
a specific date, like so:

  $cost{'1999-12-15,2000-01-14'} = 150;
  $cost{'2000-01-15,2000-02-14'} = 103;
  $cost{'2000-02-15,2000-03-14'} =  97;

and then query the cost on a specific date:

  $this_cost = $cost{'2000-02-08'};

(This example is actually where the idea for this module came from.)

Internally, the hash is actually a binary tree. Values are retrieved by
searching the tree for nodes that where the key is within range.

=head1 OPTIONS

You can specify the following options when using the module:

    tie %hash, 'Tie::RangeHash',
      {
	Separator => qr/,/,
	Type => Tie::RangeHash::TYPE_NUMBER,
	Comparison => \&my_cmp
      };

=head2 Separator

The C<Separator> specifies a regular expression used to split the lower and upper bound
keys. The default is a comma, but you can change it to anything that suits your needs.
To use two periods, set it to C<qr/\.\./>.

=head2 Type

The C<Type> specifies the sorting type. The default is C<Tie::RangeHash::TYPE_STRING>
but you can set it to C<Tie::RangeHash::TYPE_NUMBER> if the keys are numeric.

If C<Comparison> is specified, the C<Type> will be ignored.

=head2 Comparison

C<Comparison> lets you specify your own comparison subroutine, if needed. The routine
takes two arguments and compares them in much the same way C<sort> is customized:

    sub my_cmp {
      my ($A, $B) = @_;
      return ($A cmp $B);
    }

=head1 CAVEATS

The binary-tree code is spontaneously written and has a rudimentary tree-banacing
scheme. It appears to work, but has not been fully tested.

This module is incomplete... It needs the DELETE, FIRSTKEY, NEXTKEY, EXISTS and
DESTROY methods.

Duplicate and overlapping ranges are not supported. Once a range is defined,
it exists for the lifetime of the hash.

=head1 FUTURE ENHANCEMENTS

Improved binary-tree or some other mechanism for searching ranges.

Allow the user to specify "filters" to process the keys for STORE and FETCH
(for example, checking if the key is a valid date, and converting the string
representation into a numerical epoch).

Flexible handling of overlapping ranges is a needed feature: the caller should
decide whether to adjust ranges on the fly or to die on an error.

=head1 AUTHOR

Robert Rothenberg <rrwo@cpan.org>

=head1 LICENSE

Copyright (c) 2000 Robert Rothenberg. All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
