node default { }

node web1.domain.com {
include wget
include ntp
include nfsclient
include webcontent::ssl
include webcontent
}

node web2.domain.com {
include wget
include ntp
include nfsclient
include webcontent
}

node nfsserver1.domain.com {
include wget
include ntp
include nfsserver
}


node nfsserver2.domain.com {
include wget
include ntp
include nfsserver
}

node sql1.domain.com {
include wget
include ntp
include nfsclient
include postgremaster
}

node sql2.domain.com {
include wget
include ntp
include nfsclient
}
