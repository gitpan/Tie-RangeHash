use Module::Build;

my $build = Module::Build->new
    (
     module_name => 'Tie::RangeHash',
     license => 'perl',
     requires => {
       'perl'                       => '5.6.1',
       'base'                       => 0,
       'Algorithm::SkipList'        => 1.02,
       'Test::More'                 => 0,
     },
     recommends => {
     },
     create_makefile_pl => 'traditional',
     dist_author        => 'Robert Rothenberg <rrwo at cpan.org>',
     sign => 1,
);

$build->create_build_script;
