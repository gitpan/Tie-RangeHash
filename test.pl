
require 5.6.0;

use strict;
use Test;

BEGIN
  {
    eval { require Time::HiRes; import Time::HiRes qw(time) };
    if($@)
      {
	warn "Unable to import Time::HiRes::time; using default time instead";
      }
  }

BEGIN { plan tests => 53, todo => [ ] }

use Tie::RangeHash '0.51';
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


{
  print "\x23 Ordered Node Test\n";

  my $COUNT = 1000; # test 10,000 for serious benchmarking

  my @nodes = ();

  for (my $i=0; $i<$COUNT; $i++)
    {
      my $key = join(",", ($i<<1), ($i<<1)+1); 
      push @nodes, $key;
    }

  # numeric keys
  my %hash;
  tie %hash, 'Tie::RangeHash', { Type => Tie::RangeHash::TYPE_NUMBER };
  ok(1);

  print "\x23 Testing and timing $COUNT iterations\n";

  my $before_frac = time();

  for (my $i=0; $i<$COUNT; $i++)
    {
      my $key = $nodes[$i];
      $hash{$key} = $i;
    }

  my $after_frac = time();

  ok(1);

  print "\x23 Added $COUNT nodes in ", 
    sprintf('%1.3f', ($after_frac-$before_frac)), " seconds\n";

  my $success = 0;

  $before_frac = time();

  for (my $i=0; $i<$COUNT; $i++)
    {
      $success++, if ($hash{ ($i<<1) } == $i);
      $success++, if ($hash{ (($i<<1)+1) } == $i);
    } 
  $after_frac = time();

  ok($success, ($COUNT*2));

  print "\x23 ", $success, " retrievals in ",
    sprintf('%1.3f', ($after_frac-$before_frac)), " seconds\n";


  $before_frac = time();

  $success = 0;
  for (my $i=0; $i<$COUNT; $i++)
    {
      my $key = join(",", ($i<<1), ($i<<1)+1); 
      $success++, 
        if (delete( $hash{$key} ) == $i);
    }

  $after_frac = time();

  ok($success, $COUNT);

  print "\x23 Deleted $success nodes in ", 
    sprintf('%1.3f', ($after_frac-$before_frac)), " seconds\n";

  # Verify nodes deleted
  $success = 0;

  for (my $i=0; $i<$COUNT; $i++)
    {
      $success++, if (!exists($hash{ ($i<<1) } ) );
      $success++, if (!exists($hash{ (($i<<1)+1) }));
    }

  ok($success, ($COUNT*2));

  %hash = ();

  print "\x23 Random Node Test\n";

  # Pseudo-randomly shuffle
  for (my $i=0; $i<$COUNT; $i++)
    {
      my $j = rand($COUNT);

      ($nodes[$i], $nodes[$j]) = ($nodes[$j], $nodes[$i]);
    }

#  # numeric keys
#
#  untie %hash;
#
#  tie %hash, 'Tie::RangeHash', { Type => Tie::RangeHash::TYPE_NUMBER };
#  ok(1);

  print "\x23 Testing and timing $COUNT iterations\n";

  my $before_frac = time();

  for (my $i=0; $i<$COUNT; $i++)
    {
      my $key = $nodes[$i];
      $hash{$key} = $i;
    }

  my $after_frac = time();

  ok(1);

  print "\x23 Added $COUNT nodes in ", 
    sprintf('%1.3f', ($after_frac-$before_frac)), " seconds\n";

  my $success = 0;

  $before_frac = time();

  my $aux = -1;

  for (my $i=0; $i<$COUNT; $i++)
    {
      $success++, if ($hash{ ($i<<1) } != $aux);
      $success++, if ($hash{ (($i<<1)+1) } != $aux);
    }
  $after_frac = time();

  ok($success, ($COUNT*2));

   print "\x23 ", $success, " retrievals in ",
     sprintf('%1.3f', ($after_frac-$before_frac)), " seconds\n";

  $before_frac = time();

  $success = 0;
  for (my $i=0; $i<$COUNT; $i++)
    {
      my $key = join(",", ($i<<1), ($i<<1)+1); 
      $success++, 
        if (defined(delete( $hash{$key} )));
    }

  $after_frac = time();

  ok($success, $COUNT);

  print "\x23 Deleted $success nodes in ", 
    sprintf('%1.3f', ($after_frac-$before_frac)), " seconds\n";

  # Verify nodes deleted
  $success = 0;

  for (my $i=0; $i<$COUNT; $i++)
    {
      $success++, if (!exists($hash{ ($i<<1) } ) );
      $success++, if (!exists($hash{ (($i<<1)+1) }));
    }

  ok($success, ($COUNT*2));

   %hash = ();

#   print "\x23 Ordered NodeTest with ARRAY refs\n";

#   @nodes = ();

#   for (my $i=0; $i<$COUNT; $i++)
#     {
#       push @nodes, [ ($i<<1), ($i<<1)+1 ];
#     }

#   print "\x23 Testing and timing $COUNT iterations\n";

#   my $before_frac = time();

#   for (my $i=0; $i<$COUNT; $i++)
#     {
#       my $key = $nodes[$i];
#       $hash{$key} = $i;
#     }

#   my $after_frac = time();

#   ok(1);

#   print "\x23 Added $COUNT nodes in ", 
#     sprintf('%1.3f', ($after_frac-$before_frac)), " seconds\n";

#   my $success = 0;

#   $before_frac = time();

#   for (my $i=0; $i<$COUNT; $i++)
#     {
#       $success++, if ($hash{ ($i<<1) } == $i);
#       $success++, if ($hash{ (($i<<1)+1) } == $i);
#     }
#   $after_frac = time();

#   ok($success, ($COUNT*2));

#   print "\x23 ", $success, " retrievals in ",
#     sprintf('%1.3f', ($after_frac-$before_frac)), " seconds\n";

#   %hash = ();
}
