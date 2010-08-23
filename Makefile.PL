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
requires 'Catalyst::TraitFor::Request::ProxyBase';
requires 'CatalystX::Roles';
requires 'File::Copy::Recursive';
requires 'DBD::SQLite';
requires 'DBIx::Class';
requires 'DBIx::Class::Schema';
requires 'DBIx::Class::ResultSet::Data::Pageset';
requires 'DBIx::Class::ResultClass::HashRefInflator';
requires 'Moose';
requires 'Params::Validate';
requires 'YAML';
requires 'XML::Simple';
requires 'LWP::Simple';
requires 'Plack';
requires 'Plack::Middleware::ReverseProxy';
requires 'Plack::Middleware::Debug';
requires 'Plack::Middleware::Expires';
requires 'LWP';
requires 'Data::Compare';

requires 'parent';
requires 'Config::General';

catalyst;

install_script glob('script/*.pl');
auto_install;
WriteAll;
