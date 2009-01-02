use Module::Build;
Module::Build->new(
    module_name => 'Darcs::Inventory',
    license     => 'perl',
    dist_author => 'David Caldwell <david@porkrind.org>',
    requires    => { 'Digest::SHA1'  => 0,
                     'Time::Local'   => 0,
                     'Class::Accessor::Fast' => 0
    },
)->create_build_script;
