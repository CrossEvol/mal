use rust1_94_0::readline as rl;

fn read(input: &str) -> &str {
    input
}

fn eval(input: &str) -> &str {
    input
}

fn print(input: &str) -> &str {
    input
}

fn rep(input: &str) -> &str {
    print(eval(read(input)))
}

fn main() {
    loop {
        let input = rl::readline("user> ").unwrap();
        let result = rep(&input);
        println!("{}", result);
    }
}
