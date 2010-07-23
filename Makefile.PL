#!/usr/bin/env perl
# IMPORTANT: if you delete this file your app will not work as
# expected.  You have been warned.
use inc::Module::Install;

name 'PomCur';
all_from 'lib/PomCur.pm';

requires 'Catalyst::Runtime' => '5.80022';
requires 'Catalyst::Plugin::ConfigLoader';
requires 'Catalyst::Plugin::Static::Simple';
requires 'Catalyst::Plugin::Session::PerUser';
requires 'Catalyst::Action::RenderView';
requires 'Plack::Middleware::ReverseProxy';
requires 'DBD::Pg';
requires 'DBIx::Class';
requires 'DBIx::Class::Schema';
requires 'DBIx::Class::ResultSet::Data::Pageset';
requires 'Params::Validate';
requires 'YAML';
requires 'DBIx::Class';
requires 'XML::Rules';
requires 'LWP::Simple;

requires 'parent';
requires 'Config::General'; # This should reflect the config file format you've chosen
                 # See Catalyst::Plugin::ConfigLoader for supported formats
catalyst;

install_script glob('script/*.pl');
auto_install;
WriteAll;
