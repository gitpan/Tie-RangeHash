# General tests using 'tie' interface for Tie::RangeHash
# 
# You will see warnings. This is intentional.
# 
#   Multiple separators: only the first two bounds will be used in `T,U,V'
#   Overlapping key range: cannot add range `AA,B' because there exists `A,C'
#   Overlapping key range: cannot add range `A,C' because there exists `A,C'
#   Key range `B,D' exceeds defined key range `A,C'
#   Key range `1,B' exceeds defined key range `A,C'
#   Key range `1,E' exceeds defined key range `A,C'
#   Key range `H,H' is not a defined key range (found `G,I')
#   Key range `H,J' exceeds defined key range `G,I'
#   Key range `F,H' exceeds defined key range `G,I'
# 

require 5.006;

use Test;

BEGIN { plan tests => 44, todo => [ ] }

use Tie::RangeHash '0.61';
ok(1);

use warnings 'Tie::RangeHash';
ok(1);

{
  # tie
  my %hash;
  tie %hash, 'Tie::RangeHash';
  ok(1);

  # STORE

  $hash{'A,C'}  = 1;
  ok(1);

  $hash{'G,I'}  = 2;
  ok($hash{'H'}, 2);

  # Using anonymous arrays as hashes

  $hash{ ['Q', 'S'] } = 3;
  ok($hash{'R'}, 3);

  $hash{ [qw(T U V)] } = 4;
  ok($hash{'T'}, 4);
  ok($hash{'U'}, 4);
  ok($hash{'V'}, undef);

  $hash{ [qw(V)] } = 5;
  ok($hash{'V'}, 5);

  # EXISTS
  ok ( exists( $hash{'B'} ));
  ok (!exists( $hash{'D'} ));

  $hash{'D,F'} = undef;
  ok ( exists( $hash{'D'} ));
  ok (! $hash{'D'} );

  # STORE overlapping
  $hash{'AA,B'} = 2;
  ok($hash{'AA'} != 2);

  # check ranges
  ok( $hash{'A,C'}, 1 );
  ok( $hash{'A,B'}, 1 );
  ok( $hash{'B,C'}, 1 );

  # redfinition
  $hash{'A,C'} = 3;
  ok( $hash{'B'} != 3);

  # bad ranges
  ok( !defined($hash{'B,D'}) ); # overlap before
  ok( !defined($hash{'1,B'}) ); # overlap after
  ok( !defined($hash{'1,E'}) ); # beyond!

  ok( !defined($hash{'1,9'}) ); # not found

  # not found
  ok( !defined($hash{'CC'}) );
  ok( !defined($hash{'X'}) );

  # DELETE
  ok(!defined(delete( $hash{'H'} ) ) );
  ok(!defined(delete( $hash{'H,J'} ) ) );
  ok(!defined(delete( $hash{'F,H'} ) ) );

  ok(delete( $hash{'G,I'} ), 2);
  ok (!exists( $hash{'H'} ));

  ok(delete( $hash{'A,C'} ), 1);
  ok (!exists( $hash{'B'} ));

  # CLEAR

  $hash{'A,C'} = 10;
  %hash = ();
  ok(1);
  ok (!exists( $hash{'B'} ));

  # untie
  untie %hash;
  ok(1);
}

{
  # tie with string as separator
  my %hash;
  tie %hash, 'Tie::RangeHash', { Separator => '..' };
  ok(1);

  # user-defined separator
  $hash{'A..C'} = 1;
  ok(1);

  # returns the correct value
  ok($hash{'B'}, 1);

  %hash = ();
}

{
  # tie with regexp as separator
  my %hash;
  tie %hash, 'Tie::RangeHash', { Separator => qr/:{2,}/ };
  ok(1);

  # user-defined separator
  $hash{'A::C'} = 1;
  ok(1);

  # returns the correct value
  ok($hash{'B'}, 1);

  %hash = ();
}

{
  # tie with user-defined compare

  sub my_order {
    my ($A, $B) = @_;
    ($B <=> $A);
  }

  my %hash;
  tie %hash, 'Tie::RangeHash', {
      Type => Tie::RangeHash::TYPE_USER,
      Comparison => \&my_order
  };
  ok(1);

  # user-defined separator
  $hash{'3,1'} = 'A';
  $hash{'6,4'} = 'B';
  ok(1);

  # returns the correct value
  ok($hash{'2'}, 'A');

  %hash = ();
}


