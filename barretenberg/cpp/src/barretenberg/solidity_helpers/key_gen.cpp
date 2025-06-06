#include <iostream>

#include "barretenberg/plonk/composer/standard_composer.hpp"
#include "barretenberg/plonk/composer/ultra_composer.hpp"
#include "barretenberg/plonk/proof_system/verification_key/sol_gen.hpp"

#include "barretenberg/srs/global_crs.hpp"
#include "circuits/add_2_circuit.hpp"
#include "circuits/blake_circuit.hpp"
#include "circuits/ecdsa_circuit.hpp"
#include "circuits/recursive_circuit.hpp"

#include "utils/instance_sol_gen.hpp"
#include "utils/utils.hpp"

template <typename Circuit> void generate_keys(std::string output_path, std::string circuit_name)
{
    uint256_t public_inputs[4] = { 0, 0, 0, 0 };
    auto circuit = Circuit::generate(public_inputs);

    UltraComposer composer;
    std::shared_ptr<plonk::verification_key> vkey = composer.compute_verification_key(circuit);

    // Make verification key file upper case
    circuit_name.at(0) = static_cast<char>(std::toupper(static_cast<unsigned char>(circuit_name.at(0))));
    std::string flavor_prefix = "Ultra";

    std::string vk_class_name = circuit_name + flavor_prefix + "VerificationKey";
    std::string base_class_name = "Base" + flavor_prefix + "Verifier";
    std::string instance_class_name = circuit_name + flavor_prefix + "Verifier";

    {
        auto vk_filename = output_path + "/keys/" + vk_class_name + ".sol";
        std::ofstream os(vk_filename);
        bb::output_vk_sol(os, vkey, vk_class_name);
        info("VK contract written to: ", vk_filename);
    }

    {
        auto instance_filename = output_path + "/instance/" + instance_class_name + ".sol";
        std::ofstream os(instance_filename);
        output_instance(os, vk_class_name, base_class_name, instance_class_name);
        info("Verifier instance written to: ", instance_filename);
    }
}

/*
 * @brief Main entry point for the verification key generator
 *
 * 1. project_root_path: path to the solidity project root
 * 2. srs_path: path to the srs db
 */
int main(int argc, char** argv)
{
    std::vector<std::string> args(argv, argv + argc);

    if (args.size() < 4) {
        info("usage: ", args[0], "[circuit type] [output path] [srs path]");
        return 1;
    }

    const std::string circuit_flavor = args[1];
    const std::string output_path = args[2];
    const std::string srs_path = args[3];

    bb::srs::init_bn254_net_crs_factory(srs_path);
    // @todo - Add support for unrolled standard verifier. Needs a new solidity verifier contract.

    info("Generating  keys for ", circuit_flavor, " circuit");

    if (circuit_flavor == "blake") {
        generate_keys<BlakeCircuit>(output_path, circuit_flavor);
    } else if (circuit_flavor == "add2") {
        generate_keys<Add2Circuit>(output_path, circuit_flavor);
    } else if (circuit_flavor == "recursive") {
        generate_keys<RecursiveCircuit>(output_path, circuit_flavor);
    } else if (circuit_flavor == "ecdsa") {
        generate_keys<EcdsaCircuit>(output_path, circuit_flavor);
    } else {
        info("Unsupported circuit");
        return 1;
    }
    return 0;
}
