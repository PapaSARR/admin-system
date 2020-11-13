#!/usr/bin/perl -w
# 
# Version 0.1 - 27/03/2017
#
#use strict;
#use Config::IniFiles;
use ldap_lib;
#use List::Compare;
use POSIX qw(strftime);
#use IO::File;
#use DBI();
use Digest::MD5 qw(md5);
#use MIME::Base64 qw(encode_base64);
#use Getopt::Long;

my %params;
&init_config(\%params);

#my $dbh  = connect_dbi($params{'db'});

my $ldap = connect_ldap($params{'ldap'});
print "on test connecte a la base LDAP !\n";

# Declaration variables globales
my ($query,$sth,$res,$row,$user,$expire);
my ($lc);
my (@adds,@mods,@dels);
my (@SIusers,@LDAPusers);
my (%attrib);
my $today = strftime "%Y%m%d%H%M%S", localtime;

print "Date et Heure: $today\n";

# recuperation de la liste des utilisateurs LDAP
@LDAPusers = sort(get_users_list($ldap,'ou=users,dc=imss,dc=org'));
#$lc = List::Compare->new(\@SIusers, \@LDAPusers);
#@usersToDel = sort($lc->get_Ronly);
if (scalar(@LDAPusers) > 0) {
  foreach my $u (@LDAPusers) {
    my $dn = sprintf("uid=%s,%s",$u,'ou=users,dc=imss,dc=org');
    printf("User %s\n",$dn)
    #del_entry($ldap, $dn) if $options{'commit'};       
}

# $dbh->disconnect;
$ldap->unbind;

#-----------------------------------------------------------------------
# fonctions
#-----------------------------------------------------------------------
sub init_config {
  (my $ref_config) = @_;

  $$ref_config{'ldap'}{'server'}  = 'ldap1.imss.org';
  $$ref_config{'ldap'}{'version'} = '3';
  $$ref_config{'ldap'}{'port'}    = '389';
  $$ref_config{'ldap'}{'binddn'}  = 'cn=admin,dc=imss,dc=org';
  $$ref_config{'ldap'}{'passdn'}  = 'secret';

  #$$ref_config{'db'}{'database'}  = $cfg->val('db','database');
  #$$ref_config{'db'}{'server'}    = $cfg->val('db','server');
  #$$ref_config{'db'}{'user'}      = $cfg->val('db','user');    
  #$$ref_config{'db'}{'password'}  = $cfg->val('db','password');
}

#sub connect_dbi {
#  my %params = %{(shift)};
#    
#  my $dsn = "DBI:mysql:database=".$params{'database'}.";host=".$params{'server$
#  my $dbh = DBI->connect(
#                       $dsn,
#                       $params{'user'},
#                       $params{'password'},
#                       {'RaiseError' => 1}
#                     );
#  return($dbh);
}

sub sortlist {
  my @unsorted_list = @_;
  my @sorted_list = sort {
                           (split '\.', $a, 2)[1] cmp
                           (split '\.', $b, 2)[1]
                         } @unsorted_list;
  return(@sorted_list);
}

sub gen_password {
  my $clearPassword = shift;

  my $hashPassword = "{MD5}" . encode_base64( md5($clearPassword),'' );
  return($hashPassword);
}

sub calc_date {

  my $date = shift;

  my ($year,$month,$day) = split("-",$date);
  my $rec = {};
  $rec->{'date'} = $year.$month.$day."235959Z";
  chomp(my $timestamp = `date --date='$date 23:59:59' +%s`);
  $rec->{'shadow'} = ceil($timestamp/24/3600);
  return $rec;
}


