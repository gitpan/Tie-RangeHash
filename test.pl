
# To-do: Improve tests

use strict;
use Test;

BEGIN { plan tests => 1, todo => [ ] }

use Tie::RangeHash '0.30';
ok(1);

{
  # tie
  my %hash;
  tie %hash, 'Tie::RangeHash';
  ok(1);

  # STORE
  $hash{'A,C'}  = 1;
  ok(1);

  # EXISTS
  ok ( exists( $hash{'B'} ));
  ok (!exists( $hash{'D'} ));

  # STORE overlapping
  $hash{'AA,B'} = 2;
  ok($hash{'AA'} != 2);

  # check ranges
  ok( $hash{'A,C'} == 1 );
  ok( $hash{'A,B'} == 1 );
  ok( $hash{'B,C'} == 1 );

  # bad ranges
  ok( !defined($hash{'B,D'}) ); # overlap before
  ok( !defined($hash{'1,B'}) ); # overlap after
  ok( !defined($hash{'1,E'}) ); # beyond!

  ok( !defined($hash{'1,9'}) ); # not found

  # not found
  ok( !defined($hash{'CC'}) );
  ok( !defined($hash{'X'}) );

  #CLEAR
  %hash = ();
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
  ok($hash{'B'} == 1);
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
  ok($hash{'B'} == 1);
}

{
  # tie with user-defined compare



  sub my_order {
    my ($A, $B) = @_;
    ($B <=> $A);
  }

  my %hash;
  tie %hash, 'Tie::RangeHash', { Comparison => \&my_order };
  ok(1);

  # user-defined separator
  $hash{'3,1'} = 'A';
  $hash{'6,4'} = 'B';
  ok(1);

  # returns the correct value
  ok($hash{'2'} eq 'A');
}


{
  use Time::HiRes qw(time);

  # numeric keys
  my %hash;
  tie %hash, 'Tie::RangeHash', { Type => Tie::RangeHash::TYPE_NUMBER };
  ok(1);

  my $COUNT = 5000;
  my $before_frac = time;

  for (my $i=0; $i<$COUNT; $i++)
    {
      my $key = join(",", ($i*2), ($i*2)+1); 
      $hash{$key} = $i;
    }

  my $after_frac = time;

  ok(1);

  print "\x23 Added $COUNT nodes in ", 
    sprintf('%1.4f', ($after_frac-$before_frac)), " seconds\n";

  my $success = 0;

  $before_frac = time;

  for (my $i=0; $i<$COUNT; $i++)
    {
      $success++, if ($hash{ ($i*2) } == $i);
    }

  $after_frac = time;
  print "\x23 $COUNT retrievals in ",
    sprintf('%1.4f', ($after_frac-$before_frac)), " seconds\n";

  ok($success == $COUNT);
}


