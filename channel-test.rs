use std::thread;
use std::sync::mpsc;

fn main() {
  let (tx, rx) = mpsc::channel();

  for _ in 0..10 {
    let tx = tx.clone();

    thread::spawn(move || {
      let answer = 42u32;
      tx.send(answer).ok().expect("failed to send");
    });
  }
  let result = rx.recv().unwrap();
  println!("{}", result);
  /*
  match result {
    Some(x) => println!("{}", x),
    None => println!("failed to recv")
  }
  */
}
