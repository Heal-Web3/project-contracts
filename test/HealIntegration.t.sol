// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/HealDoctorNFT.sol";
import "../src/HealPrescriptionVerifier.sol";
import "../src/HealTypes.sol";

contract HealIntegrationTest is Test {
    HealDoctorNFT public nft;
    HealPrescriptionVerifier public verifier;
    
    address public regulator = address(0x1);
    address public doctor1 = address(0x2);
    address public doctor2 = address(0x3);
    address public pharmacy1 = address(0x4);
    address public pharmacy2 = address(0x5);
    address public pharmacy3 = address(0x6);
    address public pharmacy4 = address(0x7);
    
    uint256 public doctor1Key = 0xA11CE;
    uint256 public doctor2Key = 0xB0B;
    
    function setUp() public {
        // Set up addresses with private keys
        doctor1 = vm.addr(doctor1Key);
        doctor2 = vm.addr(doctor2Key);
        
        // Deploy NFT contract
        vm.prank(regulator);
        nft = new HealDoctorNFT();
        nft.setRegulator(regulator);
        
        // Deploy Verifier contract
        verifier = new HealPrescriptionVerifier(address(nft));
        
        // Mint NFTs for doctors
        vm.prank(doctor1);
        nft.mintDoctorNFT("LIC001", "Dr. Alice", "Cardiology");
        
        vm.prank(doctor2);
        nft.mintDoctorNFT("LIC002", "Dr. Bob", "Neurology");
    }
    
    function testFullFlow_MintToVerify() public {
        // Doctor 1 creates prescription
        string memory patientId = "PATIENT123";
        string memory medicine = "Amoxicillin";
        string memory dosage = "500mg twice daily";
        
        // Create prescription hash
        bytes32 prescriptionHash = keccak256(
            abi.encodePacked(patientId, medicine, dosage, block.timestamp)
        );
        
        uint256 expiry = block.timestamp + 7 days;
        
        // Doctor signs
        bytes32 ethSignedHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", prescriptionHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(doctor1Key, ethSignedHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // Pharmacy verifies
        (bool verified, string memory reason) = verifier.verifyPrescription(
            1, // doctor1's token ID
            prescriptionHash,
            signature,
            patientId,
            pharmacy1,
            expiry
        );
        
        assertTrue(verified);
        assertEq(reason, "");
        
        // Pharmacy submits
        vm.prank(pharmacy1);
        bool submitted = verifier.submitVerifiedPrescription(
            1, prescriptionHash, signature, patientId, pharmacy1, expiry
        );
        
        assertTrue(submitted);
        
        // Check counters updated
        uint256 day = block.timestamp / 86400;
        assertEq(verifier.getDoctorDailyCount(doctor1, day), 1);
        assertEq(verifier.getPatientPharmacyCount(patientId, pharmacy1, day), 1);
    }
    
    function testRegulatorRevokeFlow() public {
        // Doctor is active initially
        assertTrue(nft.isDoctorActive(1));
        
        // Create valid prescription
        string memory patientId = "PATIENT456";
        bytes32 prescriptionHash = keccak256(abi.encodePacked(patientId, "Medicine", "Dosage", block.timestamp));
        uint256 expiry = block.timestamp + 7 days;
        
        bytes32 ethSignedHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", prescriptionHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(doctor1Key, ethSignedHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // Verification passes
        (bool verified1, ) = verifier.verifyPrescription(
            1, prescriptionHash, signature, patientId, pharmacy1, expiry
        );
        assertTrue(verified1);
        
        // Regulator revokes doctor
        vm.prank(regulator);
        nft.revokeDoctorNFT(1);
        
        // Doctor is now inactive
        assertFalse(nft.isDoctorActive(1));
        
        // Verification now fails
        (bool verified2, string memory reason) = verifier.verifyPrescription(
            1, prescriptionHash, signature, patientId, pharmacy1, expiry
        );
        assertFalse(verified2);
        assertEq(reason, "Doctor license revoked");
    }
    
    function testMultiDoctorScenario() public {
        // Both doctors issue prescriptions
        for (uint i = 0; i < 5; i++) {
            string memory patientId = string(abi.encodePacked("P", vm.toString(i)));
            bytes32 prescriptionHash = keccak256(abi.encodePacked(patientId, "Med", "Dose", block.timestamp, i));
            uint256 expiry = block.timestamp + 7 days;
            
            // Alternate doctors
            uint256 doctorKey = (i % 2 == 0) ? doctor1Key : doctor2Key;
            uint256 tokenId = (i % 2 == 0) ? 1 : 2;
            
            bytes32 ethSignedHash = keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", prescriptionHash)
            );
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(doctorKey, ethSignedHash);
            bytes memory signature = abi.encodePacked(r, s, v);
            
            vm.prank(pharmacy1);
            verifier.submitVerifiedPrescription(
                tokenId, prescriptionHash, signature, patientId, pharmacy1, expiry
            );
        }
        
        // Check both doctors have correct counts
        uint256 day = block.timestamp / 86400;
        assertEq(verifier.getDoctorDailyCount(doctor1, day), 3); // i=0,2,4
        assertEq(verifier.getDoctorDailyCount(doctor2, day), 2); // i=1,3
    }
    
    function testPatientPharmacyLimitAcrossMultipleDoctors() public {
        string memory patientId = "FREQUENT_PATIENT";
        
        // Patient gets prescriptions from both doctors and visits pharmacy1 3 times
        for (uint i = 0; i < 3; i++) {
            uint256 doctorKey = (i % 2 == 0) ? doctor1Key : doctor2Key;
            uint256 tokenId = (i % 2 == 0) ? 1 : 2;
            
            bytes32 prescriptionHash = keccak256(abi.encodePacked(patientId, "Med", "Dose", block.timestamp, i));
            uint256 expiry = block.timestamp + 7 days;
            
            bytes32 ethSignedHash = keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", prescriptionHash)
            );
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(doctorKey, ethSignedHash);
            bytes memory signature = abi.encodePacked(r, s, v);
            
            vm.prank(pharmacy1);
            verifier.submitVerifiedPrescription(
                tokenId, prescriptionHash, signature, patientId, pharmacy1, expiry
            );
        }
        
        // 4th attempt should fail
        bytes32 prescriptionHash = keccak256(abi.encodePacked(patientId, "Med", "Dose", block.timestamp, 999));
        uint256 expiry = block.timestamp + 7 days;
        
        bytes32 ethSignedHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", prescriptionHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(doctor1Key, ethSignedHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        (bool verified, string memory reason) = verifier.verifyPrescription(
            1, prescriptionHash, signature, patientId, pharmacy1, expiry
        );
        
        assertFalse(verified);
        assertEq(reason, "Patient visited too many pharmacies today (max 3)");
    }
    
    // function testEventEmissions() public {
    //     // Check DoctorMinted event
    //     vm.expectEmit(true, true, false, true);
    //     emit HealDoctorNFT.DoctorMinted(3, address(0x8), "LIC003", "Dr. Carol");
        
    //     vm.prank(address(0x8));
    //     nft.mintDoctorNFT("LIC003", "Dr. Carol", "Pediatrics");
        
    //     // Check PrescriptionVerified event
    //     string memory patientId = "EVENT_PATIENT";
    //     bytes32 prescriptionHash = keccak256(abi.encodePacked(patientId, "Med", "Dose", block.timestamp));
    //     uint256 expiry = block.timestamp + 7 days;
        
    //     bytes32 ethSignedHash = keccak256(
    //         abi.encodePacked("\x19Ethereum Signed Message:\n32", prescriptionHash)
    //     );
    //     (uint8 v, bytes32 r, bytes32 s) = vm.sign(doctor1Key, ethSignedHash);
    //     bytes memory signature = abi.encodePacked(r, s, v);
        
    //     vm.expectEmit(true, false, true, true);
    //     emit HealPrescriptionVerifier.PrescriptionSubmitted(1, patientId, pharmacy1, block.timestamp);
        
    //     vm.prank(pharmacy1);
    //     verifier.submitVerifiedPrescription(1, prescriptionHash, signature, patientId, pharmacy1, expiry);
    // }

    // In test/HealIntegration.t.sol, replace the event emission test:

function testEventEmissions() public {
    // Check DoctorMinted event
    vm.expectEmit(true, true, false, true);
    emit HealDoctorNFT.DoctorMinted(3, address(0x8), "LIC003", "Dr. Carol");
    
    vm.prank(address(0x8));
    nft.mintDoctorNFT("LIC003", "Dr. Carol", "Pediatrics");
    
    // Check PrescriptionVerified event
    string memory patientId = "EVENT_PATIENT";
    bytes32 prescriptionHash = keccak256(abi.encodePacked(patientId, "Med", "Dose", block.timestamp));
    uint256 expiry = block.timestamp + 7 days;
    
    bytes32 ethSignedHash = keccak256(
        abi.encodePacked("\x19Ethereum Signed Message:\n32", prescriptionHash)
    );
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(doctor1Key, ethSignedHash);
    bytes memory signature = abi.encodePacked(r, s, v);
    
    vm.expectEmit(true, false, true, true);
    emit HealPrescriptionVerifier.PrescriptionSubmitted(1, patientId, pharmacy1, block.timestamp);
    
    vm.prank(pharmacy1);
    verifier.submitVerifiedPrescription(1, prescriptionHash, signature, patientId, pharmacy1, expiry);
}
    
    function testContractLinking() public {
        // Verifier should reference correct NFT contract
        assertEq(address(verifier.doctorNFT()), address(nft));
        
        // NFT contract should be independent
        assertTrue(address(nft) != address(verifier));
        
        // Both contracts should have correct owner
        assertEq(nft.owner(), regulator);
        assertEq(verifier.owner(), regulator);
    }
}