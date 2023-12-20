{
  description = "🦀 Templates for Nix ❄️ ";
  outputs = {self}: {
    templates.rust-cross = {
      path = ./rust-cross;
      description = "Default dev flake for Rust projects";
    };
    templates.trunks = {
      path = ./trunks;
      description = "Default dev flake for Rust Trunk projects";
    };
  };
}
