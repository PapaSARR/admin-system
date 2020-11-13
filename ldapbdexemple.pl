#!/usr/bin/perl -w
# 
# Version 0.2 - 27/03/2017
#
use strict;
use Config::IniFiles;
use ldap_lib;
use List::Compare;
use POSIX qw/strftime ceil/;
use IO::File;
use DBI();
use Digest::MD5 qw(md5);
use MIME::Base64 qw(encode_base64);
use Getopt::Long;
use Data::Dumper::Simple;

GetOptions(\%options,
           "verbose",
	   "debug",
           "commit",
	   "help|?");

if ($options{'help'}) {
  print "Usage: $0 [--verbose --debug --commit|-c --help|?]\n";
  print " ";
  print "Synchronise les utilisateurs et les groupes depuis les donnees du SI\n";
  print "Options\n";
  print "  --verbose|-v                 mode bavard\n";
  print "  --debug|-d                   mode debug\n";
  print "  --commit|-c                  applique les changements\n";
  print "  --help|-h                    affiche ce message d'aide\n";
  exit (1);
}

my $CFGFILE = "sync.cfg";
my $cfg = Config::IniFiles->new( -file => $CFGFILE );

# parametres generaux
$config{'scope'}           = $cfg->val('global','scope');

my %params;
&init_config(\%params, $cfg);
my $dbh  = connect_dbi($params{'db'});
my $ldap = connect_ldap($params{'ldap'});

# Declaration variables globales
my ($query,$sth,$res,$row,$user,$groupname,%expire);
my ($lc);
my (@adds,@mods,@dels);
my (@SIusers,@LDAPusers);
my (@SIgroups,@LDAPgroups);
my ($dn,%attrib);
my $today = strftime "%Y%m%d%H%M%S", localtime;

print "today : $today\n";

print "utilisateurs BD \n";
# recuperation des utilisateurs de la BD si
$query = $cfg->val('queries', 'get_users');
print $query."\n" ; # if $options{'debug'};
$sth = $dbh->prepare($query);
$res = $sth->execute;
while ($row = $sth->fetchrow_hashref) {
   $user = $row->{identifiant};
   push(@SIusers,$row->{identifiant});
   printf "%s %s %s %s %s\n", $row->{identifiant}, $row->{nom}, $row->{prenom}, $row->{courriel}, $row->{id_utilisateur};
}

# recuperation de la liste des utilisateurs LDAP
@LDAPusers = sort(get_users_list($ldap,$cfg->val('ldap','usersdn')));
$lc = List::Compare->new(\@SIusers, \@LDAPusers);
@dels = sort($lc->get_Ronly);
if (scalar(@dels) > 0) {
  foreach my $u (@dels) {
    $dn = sprintf("uid=%s,%s",$u,$cfg->val('ldap','usersdn'));
    printf("Suppression %s\n",$dn); #if $options{'verbose'};
    # le supprimer dans la base LDAP (écrire le code)
  }
}


$dbh->disconnect;
$ldap->unbind;


#-----------------------------------------------------------------------
# fonctions
#-----------------------------------------------------------------------
sub init_config {
  (my $ref_config, my $cfg) = @_;
    
  $$ref_config{'ldap'}{'server'}  = $cfg->val('ldap','server');
  $$ref_config{'ldap'}{'version'} = $cfg->val('ldap','version');
  $$ref_config{'ldap'}{'port'}    = $cfg->val('ldap','port'); 
  $$ref_config{'ldap'}{'binddn'}  = $cfg->val('ldap','binddn');
  $$ref_config{'ldap'}{'passdn'}  = $cfg->val('ldap','passdn');
    
  $$ref_config{'db'}{'database'}  = $cfg->val('db','database');
  $$ref_config{'db'}{'server'}    = $cfg->val('db','server');
  $$ref_config{'db'}{'user'}      = $cfg->val('db','user');    
  $$ref_config{'db'}{'password'}  = $cfg->val('db','password');
}

sub connect_dbi {
  my %params = %{(shift)};
    
  my $dsn = "DBI:mysql:database=".$params{'database'}.";host=".$params{'server'};
  my $dbh = DBI->connect(
			$dsn,
                      	$params{'user'},
		      	$params{'password'},
		      	{'RaiseError' => 1}
		      );
  return($dbh);
}

sub gen_password {    
  my $clearPassword = shift;
      
  my $hashPassword = "{MD5}" . encode_base64( md5($clearPassword),'' );
  return($hashPassword);
}

sub date2shadow {
 
  my $date = shift;
    
  chomp(my $timestamp = `date --date='$date' +%s`);
  return(ceil($timestamp/86400));
}


