
#!/usr/bin/perl -w
# ---------------------------------------------------
# Network Project 2019
# updateUser Script by Abdoulaye - M1 DCISS
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

GetOptions(\%options, "id:s", "mail:s", "datef:s","help|?");

if ($options{'help'}) {
  print "Usage: $0 [--id --mail --datef --help|?]\n";
  print " ";
  print "Modifie l'email ou/et la date d'expiration de l'utilisateur $options{'id'}\n";
  print "Options\n";
  print "  --id                         identifiant de l'utilisateur\n";
  print "  --mail                       email de l'utilisateur\n";
  print "  --datef                      date d'expiration de l'utilisateur\n";
  print "  --help|-h                    affiche ce message d'aide\n";
  exit (1);
}

if (!$options{'id'}) {
  print "Erreur, l'identifiant de l'utilisateur est requis\n";
  exit(1);
}
else{
  my $CFGFILE = "sync.cfg";
  my $cfg = Config::IniFiles->new( -file => $CFGFILE );

  # parametres generaux
  $config{'scope'} = $cfg->val('global','scope');

  my %params;
  &init_config(\%params, $cfg);
  my $dbh  = connect_dbi($params{'db'});
  my $ldap = connect_ldap($params{'ldap'});

   # Declaration variables globales
  my ($query,$sth,$stmt,$res,$row,$user,$dn);

  if ($options{'mail'}){
      #Modification dans la base de donnée
      $query = "UPDATE utilisateurs SET courriel = \"$options{'mail'}\" where identifiant = \"$options{'id'}\"";
      $stmt = $dbh->prepare($query);
      $res = $stmt->execute;
      #Modification dans l'annuaire ldap
      $dn = sprintf("uid=%s,%s",$options{'id'},$cfg->val('ldap','usersdn'));
      modify_attr($ldap,$dn,mail=>$options{'mail'});
      print "Modification de l'adresse courriel prise en compte\n";
  }
  if ($options{'datef'}){
      #Modification dans la base de donnée
      $query = "UPDATE utilisateurs SET date_expiration = \"$options{'datef'}\" where identifiant = \"$options{'id'}\"";
      $stmt = $dbh->prepare($query);
      $res = $stmt->execute;
      #Modification dans l'annuaire ldap
      $dn = sprintf("uid=%s,%s",$options{'id'},$cfg->val('ldap','usersdn'));
      modify_attr($ldap,$dn,shadowExpire=>date2shadow($options{'datef'}));
      print "Modification de la date d'expiration prise en compte\n";
  }

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


