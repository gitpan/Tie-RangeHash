# General tests using the object-oriented interface for Tie::RangeHash

require 5.006;

use Test;

BEGIN { plan tests => 20, todo => [ ] }

use Tie::RangeHash '0.71';
ok(1);

use warnings 'Tie::RangeHash';
ok(1);

{
  my $hash = new Tie::RangeHash;
  ok(1);

  $hash->add('A,C', 1);
  ok(1);

  $hash->add('G,I', 2);

  ok($hash->fetch('H'), 2);

  ok ( $hash->key_exists('B') );
  ok (!$hash->key_exists('D') );

  $hash->add('D,F', undef);
  ok ( $hash->key_exists('D') );
  ok (! $hash->fetch('D') );

  ok( $hash->fetch('A,C'), 1 );
  ok( $hash->fetch('A,B'), 1 );
  ok( $hash->fetch('B,C'), 1 );

  # Test fetch_key()

  ok( $hash->fetch_key('B'), 'A,C');

  {
    my @mini = $hash->fetch_key('B');
    ok(@mini, 2);
    ok($mini[0], 'A,C');
    ok($mini[1], 1);
  }

  {
    my %mini = $hash->fetch_key('B');
    ok(keys %mini, 1);
    ok($mini{'A,C'}, 1);
  }

  ok($hash->remove('G,I'), 2);

  $hash->clear();
  ok($hash->fetch('A'), undef);

}


