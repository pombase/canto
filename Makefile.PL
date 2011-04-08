#!/usr/bin/env perl
# IMPORTANT: if you delete this file your app will not work as
# expected.  You have been warned.
use inc::Module::Install;
use Module::Install::Catalyst; # Complain loudly if you don't have
                               # Catalyst::Devel installed or haven't said
                               # 'make dist' to create a standalone tarball.
name 'PomCur';
all_from 'lib/PomCur.pm';

requires 'Catalyst::Runtime' => '5.80022';
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Plugin::Session::PerUser';
requires 'Catalyst::Plugin::Authentication';
requires 'Catalyst::Action::RenderView';
requires 'Catalyst::Plugin::StackTrace';
requires 'Catalyst::View::JSON';
requires 'Catalyst::TraitFor::Request::ProxyBase';
requires 'CatalystX::RoleApplicator';
requires 'Catalyst::Helper';
requires 'Catalyst::Model::DBIC::Schema';
requires 'Catalyst::Plugin::Session::Store::DBI';
requires 'Catalyst::Authentication::Store::DBIx::Class';
requires 'Catalyst::View::Mason';
requires 'File::Copy::Recursive';
requires 'DBD::SQLite';
requires 'DBIx::Class';
requires 'DBIx::Class::Schema';
requires 'DBIx::Class::ResultSet::Data::Pageset';
requires 'DBIx::Class::ResultClass::HashRefInflator';
requires 'Moose';
requires 'MooseX::NonMoose';
requires 'MooseX::Role::Parameterized';
requires 'Params::Validate';
requires 'XML::Simple';
requires 'LWP::Simple';
requires 'Plack';
requires 'Plack::Middleware::ReverseProxy';
requires 'Plack::Middleware::Debug';
requires 'Plack::Middleware::Expires';
requires 'Catalyst::Engine::PSGI';
requires 'LWP';
requires 'Data::Compare';
requires 'IO::All';
requires 'Test::Exception';
requires 'JSON::Any';
requires 'HTML::Mason';
requires 'Data::Rmap';
requires 'Clone';
requires 'MIME::Types';
requires 'Catalyst::Controller::HTML::FormFu';
requires 'Lingua::EN::Inflect::Number';
requires 'GO::Parser';
requires 'Lucene';
requires 'Text::CSV';
requires 'JSON';
requires 'Try::Tiny';
requires 'Text::Similarity';
requires 'Archive::Zip';
requires 'File::Basename';
requires 'Getopt::Long';

requires 'Config::General';

test_requires 'Test::More' => '0.88';
test_requires 'Test::Deep';
test_requires 'Test::MockObject';

catalyst;

install_script glob('script/*.pl');
auto_install;
WriteAll;
