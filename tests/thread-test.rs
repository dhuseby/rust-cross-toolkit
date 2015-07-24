use std::thread;

fn main() {
  let mut i : u8 = 0;
  loop {
    i += 1;
    i %= 255;
    let _ = thread::spawn(move || {
      println!("in thread: {}", i);
    }).join();
  }
}

