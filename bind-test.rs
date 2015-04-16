use std::net::{UdpSocket, SocketAddrV4, Ipv4Addr};
use std::io::ErrorKind;

fn main() {
  let addr = SocketAddrV4::new(Ipv4Addr::new(0, 0, 0, 0), 1);
  match UdpSocket::bind(&addr) {
    Ok(..) => panic!(),
    Err(e) => assert_eq!(e.kind(), ErrorKind::PermissionDenied),
  }
}

