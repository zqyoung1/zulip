class humbug::base {
  $packages = [ "screen", "strace", "vim", "emacs23-nox", "git", "python-tz",
                "sqlite3", "ntp", "python-simplejson", "host",
                "openssh-server", "python-pip", "puppet-el",
                "iptables-persistent", "nagios-plugins-basic", "munin-node",
                "munin-plugins-extra", "postgresql-client-9.1",
		"debian-goodies", "moreutils", "python-requests", ]
  package { $packages: ensure => "installed" }


  apt::key {"A529EF65":
    source  =>  "http://apt.humbughq.com/ops.asc",
  }
  apt::sources_list {"humbug":
    ensure  => present,
    content => 'deb http://apt.humbughq.com/ops wheezy main',
  }

  group { 'humbug':
    ensure     => present,
    gid        => '1000',
  }

  user { 'humbug':
    ensure     => present,
    uid        => '1000',
    gid        => '1000',
    require    => Group['humbug'],
    shell      => '/bin/bash',
    home       => '/home/humbug',
    managehome => true,
  }

  file { '/home/humbug/.ssh/authorized_keys':
    ensure     => file,
    require    => File['/home/humbug/.ssh'],
    mode       => 600,
    owner      => "humbug",
    group      => "humbug",
    source     => 'puppet:///modules/humbug/authorized_keys',
  }

  file { '/home/humbug/.ssh':
    ensure     => directory,
    require    => User['humbug'],
    owner      => "humbug",
    group      => "humbug",
    mode       => 600,
  }

  file { '/root/.ssh/authorized_keys':
    ensure     => file,
    mode       => 600,
    owner      => "root",
    group      => "root",
    source     => 'puppet:///modules/humbug/root_authorized_keys',
  }

  # This is just an empty file.  It's used by the app to test if it's running
  # in production.
  file { '/etc/humbug-server':
    ensure     => file,
    mode       => 644,
    source     => 'puppet:///modules/humbug/humbug-server',
  }

  file { '/etc/puppet/puppet.conf':
    ensure     => file,
    mode       => 640,
    source     => 'puppet:///modules/humbug/puppet.conf',
  }

  file { '/etc/iptables/rules':
    ensure     => file,
    mode       => 600,
    source     => 'puppet:///modules/humbug/iptables/rules',
    require    => Package['iptables-persistent'],
  }

  file { '/etc/apt/apt.conf.d/02periodic':
    ensure     => file,
    mode       => 644,
    source     => 'puppet:///modules/humbug/apt/apt.conf.d/02periodic',
  }

  file { '/etc/ssh/sshd_config':
    require    => Package['openssh-server'],
    ensure     => file,
    source     => 'puppet:///modules/humbug/sshd_config',
    owner      => 'root',
    group      => 'root',
    mode       => 644,
  }

  # TODO: We may or may not want to enforce a set UID/GIT for the
  # nagios user like we do for the humbug user; we don't do that here
  # because those values differ widely between our existing systems
  # (some are "system" users with uids around 100, some have uids
  # around 1000, some have their own group, some are in the nogroup
  # group, etc.).
  user { 'nagios':
    ensure     => present,
    shell      => '/bin/bash',
    home       => '/home/nagios',
    managehome => true,
  }
  file { '/home/nagios/.ssh':
    ensure     => directory,
    require    => User['nagios'],
    owner      => "nagios",
    group      => "nagios",
    mode       => 600,
  }
  file { '/home/nagios/.ssh/authorized_keys':
    ensure     => file,
    require    => File['/home/nagios/.ssh'],
    mode       => 600,
    owner      => "nagios",
    group      => "nagios",
    source     => 'puppet:///modules/humbug/nagios_authorized_keys',
  }

  file { "/usr/lib/nagios/plugins/":
    require => Package[nagios-plugins-basic],
    recurse => true,
    purge => false,
    owner => "root",
    group => "root",
    mode => 755,
    source => "puppet:///modules/humbug/nagios_plugins/",
  }
  service { 'ssh':
    ensure     => running,
    subscribe  => File['/etc/ssh/sshd_config'],
  }

  service { 'iptables-persistent':
    ensure     => running,

    # Because there is no running process for this service, the normal status
    # checks fail.  Because puppet then thinks the service has been manually
    # stopped, it won't restart it.  This fake status command will trick puppet
    # into thinking the service is *always* running (which in a way it is, as
    # iptables is part of the kernel.)
    hasstatus => true,
    status => "/bin/true",

    # Under Debian, the "restart" parameter does not reload the rules, so tell
    # Puppet to fall back to stop/start, which does work.
    hasrestart => false,

    subscribe  => File['/etc/iptables/rules'],
  }
}
