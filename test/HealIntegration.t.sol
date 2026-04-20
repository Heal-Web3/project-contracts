// // SPDX-License-Identifier: MIT
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
    
    uint256 public doctor1Key = 0xA11CE;
    uint256 public doctor2Key = 0xB0B;
    
    function setUp() public {
        doctor1 = vm.addr(doctor1Key);
        doctor2 = vm.addr(doctor2Key);
        
        nft = new HealDoctorNFT(regulator);
        verifier = new HealPrescriptionVerifier(address(nft));
        
        HealTypes.DoctorRegistration memory reg1 = HealTypes.DoctorRegistration({
            licenseNumber: "LIC001",
            fullName: "Dr. Alice",
            specialty: "Cardiology"
        });
        
        HealTypes.DoctorRegistration memory reg2 = HealTypes.DoctorRegistration({
            licenseNumber: "LIC002",
            fullName: "Dr. Bob",
            specialty: "Neurology"
        });
        
        vm.prank(regulator);
        nft.mintDoctorNFT(doctor1, reg1);
        
        vm.prank(regulator);
        nft.mintDoctorNFT(doctor2, reg2);
    }
    
    function testFullFlow_MintToVerify() public {
        string memory patientId = "PATIENT123";
        
        bytes32 prescriptionHash = keccak256(
            abi.encodePacked(patientId, "Amoxicillin", "500mg", block.timestamp)
        );
        
        uint256 expiry = block.timestamp + 7 days;
        
        bytes32 ethSignedHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", prescriptionHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(doctor1Key, ethSignedHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        uint256 tokenId = nft.getDoctorByAddress(doctor1);
        
        (bool verified, string memory reason) = verifier.verifyPrescription(
            tokenId, prescriptionHash, signature, patientId, pharmacy1, expiry
        );
        
        assertTrue(verified);
        assertEq(reason, "");
        
        vm.prank(pharmacy1);
        bool submitted = verifier.submitVerifiedPrescription(
            tokenId, prescriptionHash, signature, patientId, pharmacy1, expiry
        );
        
        assertTrue(submitted);
    }
    
    function testRegulatorRevokeFlow() public {
        uint256 tokenId = nft.getDoctorByAddress(doctor1);
        assertTrue(nft.isDoctorActive(tokenId));
        
        string memory patientId = "PATIENT456";
        bytes32 prescriptionHash = keccak256(abi.encodePacked(patientId, "Med", "Dose", block.timestamp));
        uint256 expiry = block.timestamp + 7 days;
        
        bytes32 ethSignedHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", prescriptionHash)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(doctor1Key, ethSignedHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        (bool verified1, ) = verifier.verifyPrescription(
            tokenId, prescriptionHash, signature, patientId, pharmacy1, expiry
        );
        assertTrue(verified1);
        
        vm.prank(regulator);
        nft.revokeDoctorNFT(tokenId);
        
        assertFalse(nft.isDoctorActive(tokenId));
        
        (bool verified2, string memory reason) = verifier.verifyPrescription(
            tokenId, prescriptionHash, signature, patientId, pharmacy1, expiry
        );
        assertFalse(verified2);
        assertEq(reason, "Doctor license revoked");
    }
    
    function testDoctorDailyLimit() public {
        uint256 tokenId = nft.getDoctorByAddress(doctor1);
        uint256 expiry = block.timestamp + 7 days;
        
        // Submit 30 prescriptions
        for (uint256 i = 0; i < 30; i++) {
            string memory pid = string(abi.encodePacked("P", vm.toString(i)));
            bytes32 pHash = keccak256(abi.encodePacked(pid, "Med", "Dose", block.timestamp, i));
            
            bytes32 eHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", pHash));
            (uint8 vVal, bytes32 rVal, bytes32 sVal) = vm.sign(doctor1Key, eHash);
            bytes memory sig = abi.encodePacked(rVal, sVal, vVal);
            
            vm.prank(pharmacy1);
            verifier.submitVerifiedPrescription(tokenId, pHash, sig, pid, pharmacy1, expiry);
        }
        
        // 31st should fail
        string memory finalPatientId = "P31";
        bytes32 finalHash = keccak256(abi.encodePacked(finalPatientId, "Med", "Dose", block.timestamp, uint256(999)));
        
        bytes32 finalEHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", finalHash));
        (uint8 vFinal, bytes32 rFinal, bytes32 sFinal) = vm.sign(doctor1Key, finalEHash);
        bytes memory finalSig = abi.encodePacked(rFinal, sFinal, vFinal);
        
        (bool verified, string memory reason) = verifier.verifyPrescription(
            tokenId, finalHash, finalSig, finalPatientId, pharmacy1, expiry
        );
        
        assertFalse(verified);
        assertEq(reason, "Doctor exceeded 30 prescriptions today");
    }
}