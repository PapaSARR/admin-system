
#!/usr/bin/perl -w

# ---------------------------------------------------
# Network Project 2019
# afficheUsers Script by Abdoulaye - M1 DCISS
# --------------------------------------------------


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

GetOptions(\%options, "help|?");

if ($options{'help'}) {
  print "Usage: $0\n";
  print " ";
  print "Liste les utilisateurs pr�sents dans la base de donn�e\n";
  print "Options\n";
  print "  --help|-h                    affiche ce message d'aide\n";
  exit (1);
}
my $CFGFILE = "sync.cfg";
my $cfg = Config::IniFiles->new( -file => $CFGFILE );

# parametres generaux
$config{'scope'} = $cfg->val('global','scope');

my %params;
&init_config(\%params, $cfg);
my $dbh  = connect_dbi($params{'db'});
my $ldap = connect_ldap($params{'ldap'});

# Declaration variables globales
my ($query,$sth,$res,$row,$user,$groupname,%expire);
print "Liste des utilisateurs de la BD \n";
# recuperation des utilisateurs de la BD si
$query = $cfg->val('queries', 'get_users');
$sth = $dbh->prepare($query);
$res = $sth->execute;
while ($row = $sth->fetchrow_hashref) {
   $user = $row->{identifiant};
   printf "%s %s %s %s %s\n", $row->{identifiant}, $row->{nom}, $row->{prenom},$row->{courriel}, $row->{id_utilisateur};
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





