node default { }

node web1.domain.com {
include wget
include ntp
include nfsclient
include webcontent::ssl
}

node web2.domain.com {
include wget
include ntp
include nfsclient
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
}

node sql2.domain.com {
include wget
include ntp
include nfsclient
}
