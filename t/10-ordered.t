
require 5.6.0;

use strict;
use Test;

BEGIN { plan tests => 6, todo => [ ] }

use Tie::RangeHash '0.71';
ok(1);

{
  my $COUNT = 20000; # test 10,000 for serious benchmarking

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

  for (my $i=0; $i<$COUNT; $i++)
    {
      my $key = $nodes[$i];
      $hash{$key} = $i;
    }

  ok(1);

  my $success = 0;

  for (my $i=0; $i<$COUNT; $i++)
    {
      $success++, if ($hash{ ($i<<1) } == $i);
      $success++, if ($hash{ (($i<<1)+1) } == $i);
    } 
  ok($success, ($COUNT*2));

  $success = 0;
  for (my $i=0; $i<$COUNT; $i++)
    {
      my $key = join(",", ($i<<1), ($i<<1)+1); 
      $success++, 
        if (delete( $hash{$key} ) == $i);
    }

  ok($success, $COUNT);

  # Verify nodes deleted
  $success = 0;

  for (my $i=0; $i<$COUNT; $i++)
    {
      $success++, if (!exists($hash{ ($i<<1) } ) );
      $success++, if (!exists($hash{ (($i<<1)+1) }));
    }

  ok($success, ($COUNT*2));

}

