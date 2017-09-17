class postgremaster {
class { 'postgresql::server':
  ip_mask_allow_all_users    => '0.0.0.0/0',
  postgres_password          => 'Password1',
}

postgresql::server::role { 'ruby-rails-sample':
	createdb => true,
        superuser => true,
	password_hash => postgresql_password('ruby-rails-sample', 'Password1'),
}


postgresql::server::pg_hba_rule { 'allow application network to access app database':
  order		     => '2',
  type               => 'local',
  database           => 'all',
  user               => 'all',
  auth_method        => 'md5',
  target             => '/var/lib/pgsql/data/pg_hba.conf',
}


}
