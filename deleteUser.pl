#!/usr/bin/perl -w
# ---------------------------------------------------
# Network Project 2019
# deleteUser Script by Abdoulaye - M1 DCISS
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

GetOptions(\%options,
           "id:s",
	   "help|?");

if ($options{'help'}) {
  print "Usage: $0 [--id --help|?]\n";
  print " ";
  print "Supprime un utilisateur du système d'information SI\n";
  print "Options\n";
  print "  --id                         identifiant de l'utilisateur à supprimer\n";
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
my ($query,$sth,$stmt,$res,$row,$user,$dn,@SIusers);

# recuperation des utilisateurs de la BD si
$query = $cfg->val('queries', 'get_users');
$sth = $dbh->prepare($query);
$res = $sth->execute;
while ($row = $sth->fetchrow_hashref) {
   $user = $row->{identifiant};
   push(@SIusers,$user);
}
if(!($options{'id'} ~~ @SIusers)){
        printf("Erreur, l'utilisateur %s n'existe pas dans la base de donnees\n",$options{'id'});
        exit(1);
}else{
#Suppression de la base de données
$query = "DELETE FROM utilisateurs where identifiant = \"$options{'id'}\"";
$stmt = $dbh->prepare($query);
$res = $stmt->execute;
# Suppression de l'annuaire ldap
$dn = sprintf("uid=%s,%s",$options{'id'},$cfg->val('ldap','usersdn'));
del_entry($ldap,$dn);
printf("L'utilisateur %s vient d'etre supprime du si\n",$options{'id'});
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


