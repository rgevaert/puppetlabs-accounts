#
#
# parameters:
# [*name*] Name of user
# [*locked*] Whether the user account should be locked.
# [*sshkeys*] List of ssh public keys to be associated with the
# user.
# [*managehome*] Whether the home directory should be removed with accounts
# [*manage_primary_group*] Minage the primary group, default true
#
define accounts::user(
  $ensure               = 'present',
  $shell                = '/bin/bash',
  $comment              = $name,
  $home                 = undef,
  $home_mode            = undef,
  $uid                  = undef,
  $gid                  = undef,
  $groups               = [ ],
  $membership           = 'minimum',
  $manage_primary_group = true,
  $password             = '!!',
  $locked               = false,
  $sshkeys              = [],
  $purge_sshkeys        = false,
  $managehome           = true,
  $bashrc_content       = undef,
  $bash_profile_content = undef,
  $user_provider        = undef,
  $forcelocal           = true,
) {
  validate_re($ensure, '^present$|^absent$')
  validate_bool($locked, $managehome, $purge_sshkeys, $manage_primary_group)
  validate_re($shell, '^/')
  validate_string($comment, $password)
  validate_array($groups, $sshkeys)
  validate_re($membership, '^inclusive$|^minimum$')
  if $bashrc_content {
    validate_string($bashrc_content)
  }
  if $bash_profile_content {
    validate_string($bash_profile_content)
  }
  if $home {
    validate_re($home, '^/')
    # If the home directory is not / (root on solaris) then disallow trailing slashes.
    validate_re($home, '^/$|[^/]$')
  }

  if $home {
    $home_real = $home
  } elsif $name == 'root' {
    $home_real = $::osfamily ? {
      'Solaris' => '/',
      default   => '/root',
    }
  } else {
    if($forcelocal){
      $home_real = $::osfamily ? {
        'Solaris' => "/export/home/${name}",
        default   => "/home/${name}",
      }
    }else{
      $home_real = undef
    }
  }

  if $uid != undef {
    validate_re($uid, '^\d+$')
  }

  if( ($gid == undef) and $forcelocal) {
    $_gid = $name
  }elsif $gid == undef {
    $_gid = $gid
  } else {
    validate_re($gid, '^\d+$')
    $_gid = $gid
  }


  if $locked {
    case $::operatingsystem {
      'debian', 'ubuntu' : {
        $_shell = '/usr/sbin/nologin'
      }
      'solaris' : {
        $_shell = '/usr/bin/false'
      }
      default : {
        $_shell = '/sbin/nologin'
      }
    }
  } else {
    $_shell = $shell
  }

  user { $name:
    ensure         => $ensure,
    shell          => $_shell,
    comment        => "${comment}", # lint:ignore:only_variable_string
    home           => $home_real,
    uid            => $uid,
    gid            => $_gid,
    groups         => $groups,
    membership     => $membership,
    managehome     => $managehome,
    password       => $password,
    purge_ssh_keys => $purge_sshkeys,
    provider       => $user_provider,
    forcelocal     => $forcelocal,
  }

  # use $gid instead of $_gid since `gid` in group can only take a number
  if($manage_primary_group) {
    group { $name:
      ensure => $ensure,
      gid    => $gid,
    }

    if $ensure == 'present' {
      Group[$name] -> User[$name]
    } else {
      User[$name] -> Group[$name]
    }

    $home_dir_requirement = [ User[$name], Group[$name] ]
  }else {
    $home_dir_requirement = [ User[$name] ]
  }

  accounts::home_dir { $home_real:
    ensure               => $ensure,
    mode                 => $home_mode,
    managehome           => $managehome,
    bashrc_content       => $bashrc_content,
    bash_profile_content => $bash_profile_content,
    user                 => $name,
    group                => $_gid,
    sshkeys              => $sshkeys,
    require              => $home_dir_requirement,
  }
}
