
# Test for bug in rt.cpan.org ticket 1887

require 5.006;

use Test;

BEGIN { plan tests => 3, todo => [ ] }

use Tie::RangeHash '0.72';

# use numeric mode
tie %T, Tie::RangeHash, {Type => Tie::RangeHash::TYPE_NUMBER}; 

# assign two decimal ranges
$T{'0,.499'}    = 'A'; 
$T{'0.500,1.9'} = 'B';

ok($T{.4}, 'A');
ok($T{.5}, 'B');
ok($T{.6}, 'B');
