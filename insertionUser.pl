#!/usr/bin/perl -w
# ---------------------------------------------------
# Network Project 2019
# insertionUser Script by Abdoulaye - M1 DCISS
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

GetOptions(\%options, "id:s", "nom:s", "prenom:s", "passwd:s", "mail:s",
                         "idu:i", "idg:i", "datef:s", "help|?");
if($options{'help'} || !$options{'id'} || !$options{'nom'} ||
         !$options{'prenom'} || !$options{'passwd'} || !$options{'mail'} ||
         !$options{'idu'} || !$options{'idg'} || !$options{'datef'}){
                print "Usage: $0 [ --id --nom --prenom --passwd --mail --idu --idg --datef --help|?]\n";
                print " ";
                print "Ajoute un utilisateur dans la base de donnee si et l'annuaire ldap\n";
                print "Options\n";
                print " --id                          identifiant de l'utilisateur\n";
                print " --nom                         nom de l'utilisateur\n";
                print " --prenom                      prenom de l'utilsateur\n";
                print " --passwd                      mot de passe de l'utilisateur\n";
                print " --mail                        email de l'utilisateur\n";
                print " --idu                         num�ro de l'utilisateur\n";
                print " --idg                         num�ro de groupe de l'utilisateur\n";
                print " --datef                       date d'expiration de l'utilisateur\n";
                print " --help|-h                    affiche ce message d'aide\n";
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
my ($sql,$stmt,$user,$userdn,%attrs);
my ($query,$sth,$res,$row,@SIusers);
#On est connecté, $dbh est le HANDLE de la base de données

$query = $cfg->val('queries', 'get_users');
$sth = $dbh->prepare($query);
$res = $sth->execute;
while ($row = $sth->fetchrow_hashref) {
   $user = $row->{identifiant};
   push(@SIusers,$user);
}
if($options{'id'} ~~ @SIusers){
        print"Erreur, l'utilisateur existe d�j� dans la base de donn�es\n";
        exit(1);
}else{
$stmt = $dbh->prepare($cfg->val('queries','insert_user'));
$stmt->execute($options{'id'}, $options{'nom'}, $options{'prenom'},
                        gen_password($options{'passwd'}), $options{'mail'}, $options{'idu'},
                        $options{'idg'}, $options{'datef'});

$user = $options{'id'};
$userdn = $cfg->val('ldap','usersdn');
%attrs = ('cn'=>join(" ",$options{'prenom'},$options{'nom'}),
          'sn'=>$options{'nom'},
          'givenName'=>$options{'prenom'},
          'mail'=>$options{'mail'},
          'uidNumber'=>$options{'idu'},
          'gidNumber'=>$options{'idg'},
          'homeDirectory'=>"/home/".$options{'id'},
          'loginShell'=>"/bin/bash",
          'userPassword'=> gen_password($options{'passwd'}),
          'shadowExpire'=> date2shadow($options{'datef'})
          );
add_user($ldap,$user,$userdn,%attrs);
printf("L'utilisateur %s vient d'etre ajoute dans le si\n",$user);
$dbh->disconnect;
$ldap->unbind;
}



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



