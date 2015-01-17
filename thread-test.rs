use std::thread::Thread;

fn main() {
  let mut i : u8 = 0;
  loop {
    i += 1;
    let t = Thread::spawn(move || {
      println!("in thread: {}", i);
      Thread::park();
    });
    t.unpark();
  }
}

