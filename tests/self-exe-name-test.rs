use std::os;

fn main() {
  match os::self_exe_name() {
    Some(exe_path) => println!("Path of this executable is: {}", exe_path.display()),
    None => println!("Unable to get the path of this executable!")
  };
}
