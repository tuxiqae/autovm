{specialArgs}: {
  terraform.required_providers.null.source = "hashicorp/null";

  resource.null_resource.result_type = {
    triggers = {
      inherit (specialArgs) imagePath;
    };

    provisioner.local-exec = {
      command = "file ${specialArgs.imagePath}/${specialArgs.imagePath.name}.vhd";
    };
  };
}
