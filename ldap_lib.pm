#!/usr/bin/perl -w
use strict;
package ldap_lib;
use Net::LDAP;

# $Id: ldap_lib.pm,v 0.11 - 30/03/2017  $
#

use vars       qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
use Exporter;
$VERSION = 1.00;

@ISA = qw(Exporter);
use vars qw(%config %options);

@EXPORT = qw(
             connect_ldap
             exist_entry
             read_entry
             read_array_entry
             del_entry    
             add_attr    
             modify_attr    
             del_attr
             get_users_list
             get_group_members
             get_posixgroup_members
             add_user
             get_aliases_list
             get_groups_list
             is_posixgroup_member
             posixgroup_add_user
             get_posixgroups_list
		 	 add_posixgroup
             add_alias
             add_group
             get_dn
             get_dn_list
			 %config
             %options
	    );


sub connect_ldap {
  my %params = %{(shift)};
  
  my $ldap = Net::LDAP->new($params{'server'},
 		            port =>  $params{'port'},
                            version => $params{'version'},
                            timeout => 60)
  or die "erreur LDAP: Can't contact ldap server ". $params{'server'};

  $ldap->bind($params{'binddn'}, 
              password => $params{'passdn'} );
  return($ldap);
}


sub exist_entry {
  my ($ldap, $base, $filter) = @_;
  
  my $mesg = $ldap->search (    
                       base   => $base,
	                   scope  => $config{'scope'},
	                   filter => "$filter"
                           );
  $mesg->code && die $mesg->error;
  return ($mesg->count ne 0);
}


sub read_entry {

  my ($ldap, $base, $filter, @attributes) = @_;
  my $mesg = $ldap->search ( # perform a search
                              base   => $base,
                              scope => $config{'scope'},
                              filter => "$filter"
                             );
  my %info;	
  $mesg->code && die $mesg->error;
  foreach my $entry ($mesg->all_entries) {
    foreach my $attr (@attributes) {
      $info{$attr} = defined($entry->get_value($attr)) ? $entry->get_value($attr) : "";
    }
  }
  return %info;
}


sub read_array_entry {

  my ($ldap, $base, $filter, @attributes) = @_;
  my $mesg = $ldap->search ( # perform a search
                              base   => $base,
                              scope => $config{'scope'},
                              filter => "$filter"
                             );
  my %info;	
  $mesg->code && die $mesg->error;
  foreach my $entry ($mesg->all_entries) {
    foreach my $attr (@attributes) {
      my @values = defined($entry->get_value($attr)) ? $entry->get_value($attr) : ();
      $info{$attr} = scalar(@values) > 1 ? [ @values ] : $values[0];
    }
  }
  return %info;
}


sub del_entry {
  
  my ($ldap, $dn) = @_;

  my $modify = $ldap->delete ($dn);
  $modify->code && die "failed to delete entry : ", $modify->error ;
}


sub add_attr {

  my ($ldap, $dn, @adds) = @_;
  my $modify = $ldap->modify (dn => $dn,
                              changes => [ 
	                                   add => [ @adds ]
                                         ]      
                             );
  $modify->code && warn "failed to modify entry: ", $modify->error ;
}

sub modify_attr {

  my ($ldap, $dn, @mods) = @_;
  my $modify = $ldap->modify (dn => $dn,
                              'replace' => { @mods }
                             );
  $modify->code && warn "failed to modify entry: ", $modify->error ;
}


sub del_attr {
    
  my ($ldap, $dn, @dels) = @_;
  my $modify = $ldap->modify (dn => $dn,
                                    changes => [
                                               delete => [ @dels ]
                                               ]
                             );
  $modify->code && warn "failed to modify entry: ", $modify->error ;
}

sub get_users_list {
  my ($ldap, $base) = @_;
    
  my @members = ();
  my $uid;
  my $mesg = $ldap->search ( # perform a search
                             base   => $base,
                             filter => "(objectClass=posixAccount)",
                             attrs => ['uid']
                           );
  $mesg->code && die $mesg->error;
   
  foreach my $entry ($mesg->all_entries) {
    foreach my $value ($entry->get_value("uid")) {
      push @members,$value;
    }
  }
  return @members;
}

sub is_posixgroup_member {
  my ($ldap, $base, $group, $user) = @_;
  my $mesg = $ldap->search(
	            base   => $base,
	            filter => "(&(cn=$group)(memberUid=$user))"
	     );
  $mesg->code && die $mesg->error;
  return ( $mesg->count ne 0 );
}


sub posixgroup_add_user {
  my ($ldap, $base, $group, $user) = @_;
  my @adds;
  my $is_member = is_posixgroup_member($ldap, $base, $group, $user);
  if ($is_member == 1 ) {
    return 0;
  }
  else {
    my $dn = "cn=$group,$base";
    push (@adds, 'memberUid' =>  $user);
    add_attr($ldap, $dn, @adds);
  }	    
  return 1;
}


sub add_posixgroup {

  my ($ldap, $groupsdn, %attr) = @_;

  my $dn = "cn=".$attr{'cn'}.",$groupsdn";
  print $dn."\n" if $options{'verbose'};
  my $add = $ldap->add (dn => $dn,
                              attr => [
                                     'objectclass' => ['top','posixGroup' ],
                                     'cn'   => $attr{'cn'},
                                     'gidNumber'   => $attr{'gidNumber'},
                                     'description'   => $attr{'description'}
                                      ]
                       );
  $add->code && warn "failed to add entry: ", $add->error ;
}


sub get_group_members {
  my ($ldap, $base, $group) = @_;

  my @members = ();
  my $uid;
  my $mesg = $ldap->search ( # perform a search
                           base   => $base,
                           filter => "(cn=$group)",
                           attrs => ['member']
                         );
  $mesg->code && die $mesg->error;

  foreach my $entry ($mesg->all_entries) {
    foreach my $value ($entry->get_value("member")) {
      if ($value =~ /uid/) {
        ($uid = $value) =~ s/uid=(\w+),ou=(.*)$/$1/;
        push @members,$uid;
      }
    }
  }
  return @members;
}

sub get_posixgroup_members {
  my ($ldap, $base, $group) = @_;

  my @members = ();
  my $uid;
  my $mesg = $ldap->search ( # perform a search
                           base   => $base,
                           filter => "(cn=$group)",
                           attrs => ['memberUid']
                         );
  $mesg->code && die $mesg->error;

  foreach my $entry ($mesg->all_entries) {
    foreach my $value ($entry->get_value("memberUid")) {
      push @members,$value;
    }
  }
  return @members;
}

sub add_user {
    
  my ($ldap, $user, $usersdn, %attr) = @_;

  my $dn = "uid=$user,$usersdn";
  print $dn."\n" if $options{'verbose'};    
  my $add = $ldap->add (dn => $dn,
                        attr => [
                                      'objectclass' => ['top','person','organizationalPerson','inetOrgPerson',
					                 'posixAccount','shadowAccount' ],
                                      'uid'   => $user,				 
                                      'cn'   => $attr{'cn'},
                                      'sn'   => $attr{'sn'},
                                      'givenName' => $attr{'givenName'},
                                      'uidNumber'   => $attr{'uidNumber'},
                                      'gidNumber'   => $attr{'gidNumber'},
			              'homeDirectory' => $attr{'homeDirectory'},
			              'description'   => $attr{'sn'},
                                      'userPassword'   => $attr{'userPassword'},
				      'loginShell'     => $attr{'loginShell'},
				      'mail'     => $attr{'mail'},
                                      'shadowLastChange' => 0,
                                      'shadowMin' => 0,
                                      'shadowMax' => 999999,
                                      'shadowWarning' => 7,
                                      'shadowInactive' => -1,
                                      'shadowExpire' => $attr{'shadowExpire'},
                                      'shadowFlag' => 0
                                     ]
                            );
    
  $add->code && warn "failed to add entry: ", $add->error ;
}

sub get_aliases_list {
  my ($ldap, $base) = @_;
    
  my @aliases = ();
  my $mesg = $ldap->search ( # perform a search
                             base   => $base,
                             filter => "(objectClass=MailAlias)",
                             attrs => ['cn']
                           );
  $mesg->code && die $mesg->error;
   
  foreach my $entry ($mesg->all_entries) {
    foreach my $value ($entry->get_value("cn")) {
      push @aliases,$value;
    }
  }
  return @aliases;
}

sub get_groups_list {
  my ($ldap, $base) = @_;
    
  my @groups = ();
  my $mesg = $ldap->search ( # perform a search
                             base   => $base,
                             filter => "(objectClass=groupOfNames)",
                             attrs => ['cn']
                           );
  $mesg->code && die $mesg->error;
   
  foreach my $entry ($mesg->all_entries) {
    foreach my $value ($entry->get_value("cn")) {
      push @groups,$value;
    }
  }
  return @groups;
}


sub get_posixgroups_list {
  my ($ldap, $base) = @_;
    
  my @groups = ();
  my $mesg = $ldap->search ( # perform a search
                             base   => $base,
                             filter => "(objectClass=posixGroup)",
                             attrs => ['cn']
                           );
  $mesg->code && die $mesg->error;
   
  foreach my $entry ($mesg->all_entries) {
    foreach my $value ($entry->get_value("cn")) {
      push @groups,$value;
    }
  }
  return @groups;
}


sub add_alias {
    
  my ($ldap, $aliasesdn, %attr) = @_;

  my $dn = "cn=".$attr{'cn'}.",$aliasesdn";
  print $dn."\n" if $options{'verbose'};
  my $add = $ldap->add (dn => $dn,
                              attr => [
                                    'objectclass' => ['top','inetOrgPerson', 'MailAlias' ],
                                    'cn'   => $attr{'cn'},
                                    'sn'   => $attr{'sn'},
		                    @{ $attr{'mail'} },
                                    @{ $attr{'maildrop'} }
                                      ]
                        );
  $add->code && warn "failed to add entry: ", $add->error ;
}


sub add_group {
    
  my ($ldap, $groupsdn, %attr) = @_;

  my $dn = "cn=".$attr{'cn'}.",$groupsdn";
  print $dn."\n" if $options{'verbose'};
  my $add = $ldap->add (dn => $dn,
                              attr => [
                                     'objectclass' => ['top','groupOfNames' ],
                                     'cn'   => $attr{'cn'},
                                      @{ $attr{'members'} }
                                      ]
                       );
  $add->code && warn "failed to add entry: ", $add->error ;
}

sub get_dn {
  my ($ldap, $base, $filter) = @_;
 
  my $dn;
  my $mesg = $ldap->search (    
                           base   => $base,
	                   scope  => $config{'scope'},
	                   filter => "$filter"
                            );
  $mesg->code && die $mesg->error;
  foreach my $entry ($mesg->all_entries) {
    $dn= $entry->dn;
  }
  chomp($dn);
  if ($dn eq '') {
    return undef;
  }
  return $dn;
}

sub get_dn_list {
  my ($ldap, $base, $filter) = @_;
    
  my @list = ();
  my $mesg = $ldap->search ( # perform a search
                             base   => $base,
                             scope  => $config{'scope'},
                             filter => "$filter",
                           );
  $mesg->code && die $mesg->error;
   
  foreach my $entry ($mesg->all_entries) {
    foreach my $value ($entry->dn) {
      push @list,$value;
    }
  }
  return @list;
}

1;

