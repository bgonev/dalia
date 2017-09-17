class webcontent {
file { 'ssl.conf':
    path    => '/etc/nginx/sites-available/ssl.conf',
    ensure  => file,
 #   require => file['/etc/nginx/sites-available'],
    source  => "puppet:///modules/webcontent/ssl.conf"
  }

file { 'webshare':
    path    => '/webshare',
    ensure  => 'directory',
    owner => 'root',
    group => 'root',
  }


if $hostname == 'web1.domain.com'  {
mount { "/webshare":
        device  => "nfsserver1:/webshare",
        fstype  => "nfs",
        ensure  => "mounted",
        options => "rw,nolock",
        atboot  => "true",
    }
} else {
mount { "/webshare":
        device  => "nfsserver2:/webshare",
        fstype  => "nfs",
        ensure  => "mounted",
        options => "rw,nolock",
        atboot  => "true",
    }
}

file { 'rails.sh':
    path    => '/tmp/rails.sh',
    ensure  => 'file',
    owner => 'centos',
    group => 'centos',
    mode => '0755',
    source => 'puppet:///modules/webcontent/rails.sh',
  }

file { 'app.sh':
    path    => '/tmp/app.sh',
    ensure  => 'file',
    owner => 'centos',
    group => 'centos',
    mode => '0755',
    source => 'puppet:///modules/webcontent/app.sh',
  }

}
