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





// pragma solidity ^0.8.20;

// import "forge-std/Test.sol";
// import "forge-std/console.sol";
// import "../src/HealDoctorNFT.sol";
// import "../src/HealPrescriptionVerifier.sol";
// import "../src/HealTypes.sol";

// contract HealIntegrationTest is Test {
//     HealDoctorNFT public nft;
//     HealPrescriptionVerifier public verifier;
    
//     // Test addresses
//     address public regulator = makeAddr("regulator");
//     address public doctor1 = makeAddr("doctor1");
//     address public doctor2 = makeAddr("doctor2");
//     address public doctor3 = makeAddr("doctor3");
//     address public pharmacy1 = makeAddr("pharmacy1");
//     address public pharmacy2 = makeAddr("pharmacy2");
//     address public pharmacy3 = makeAddr("pharmacy3");
//     address public pharmacy4 = makeAddr("pharmacy4");
//     address public maliciousActor = makeAddr("malicious");
//     address public contractOwner;
    
//     // Private keys for signing
//     uint256 public doctor1Key = 0xA11CE;
//     uint256 public doctor2Key = 0xB0B;
//     uint256 public doctor3Key = 0xC0C;
//     uint256 public maliciousKey = 0xBAD;
    
//     function setUp() public {
//         // Set contract owner
//         contractOwner = address(this);
        
//         // Set up addresses with private keys
//         doctor1 = vm.addr(doctor1Key);
//         doctor2 = vm.addr(doctor2Key);
//         doctor3 = vm.addr(doctor3Key);
//         maliciousActor = vm.addr(maliciousKey);
        
//         // Deploy contracts (this contract is the owner)
//         nft = new HealDoctorNFT(regulator);
//         verifier = new HealPrescriptionVerifier(address(nft));
        
//         // Register doctors
//         _registerDoctor(doctor1, "LIC001", "Dr. Alice Smith", "Cardiology");
//         _registerDoctor(doctor2, "LIC002", "Dr. Bob Johnson", "Neurology");
//         _registerDoctor(doctor3, "LIC003", "Dr. Carol Williams", "Pediatrics");
        
//         // Label addresses
//         vm.label(regulator, "Regulator");
//         vm.label(doctor1, "Dr. Alice");
//         vm.label(doctor2, "Dr. Bob");
//         vm.label(doctor3, "Dr. Carol");
//         vm.label(pharmacy1, "Pharmacy 1");
//         vm.label(pharmacy2, "Pharmacy 2");
//         vm.label(pharmacy3, "Pharmacy 3");
//         vm.label(pharmacy4, "Pharmacy 4");
//         vm.label(maliciousActor, "Malicious Actor");
//         vm.label(contractOwner, "Contract Owner");
//     }
    
//     // ============ HELPER FUNCTIONS ============
    
//     function _registerDoctor(address doctor, string memory license, string memory name, string memory specialty) internal {
//         HealTypes.DoctorRegistration memory reg = HealTypes.DoctorRegistration({
//             licenseNumber: license,
//             fullName: name,
//             specialty: specialty
//         });
        
//         vm.prank(regulator);
//         nft.mintDoctorNFT(doctor, reg);
//     }
    
//     function _createPrescriptionHash(
//         string memory patientId,
//         string memory medicine,
//         string memory dosage,
//         uint256 timestamp
//     ) internal pure returns (bytes32) {
//         return keccak256(abi.encodePacked(patientId, medicine, dosage, timestamp));
//     }
    
//     function _signPrescription(bytes32 prescriptionHash, uint256 privateKey) internal pure returns (bytes memory) {
//         bytes32 ethSignedHash = keccak256(
//             abi.encodePacked("\x19Ethereum Signed Message:\n32", prescriptionHash)
//         );
//         (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethSignedHash);
//         return abi.encodePacked(r, s, v);
//     }
    
//     // ============ CORE FLOW TESTS ============
    
//     function testFullFlow_SinglePrescription() public {
//         string memory patientId = "PATIENT001";
//         uint256 tokenId = nft.getDoctorByAddress(doctor1);
//         bytes32 hash = _createPrescriptionHash(patientId, "Amoxicillin", "500mg", block.timestamp);
//         bytes memory signature = _signPrescription(hash, doctor1Key);
//         uint256 expiry = block.timestamp + 7 days;
        
//         (bool verified, string memory reason) = verifier.verifyPrescription(
//             tokenId, hash, signature, patientId, pharmacy1, expiry
//         );
        
//         assertTrue(verified);
//         assertEq(reason, "");
        
//         uint256 day = block.timestamp / 86400;
//         assertEq(verifier.getDoctorDailyCount(doctor1, day), 0);
        
//         vm.prank(pharmacy1);
//         verifier.submitVerifiedPrescription(
//             tokenId, hash, signature, patientId, pharmacy1, expiry
//         );
        
//         assertEq(verifier.getDoctorDailyCount(doctor1, day), 1);
//         assertTrue(verifier.isPrescriptionUsed(hash));
//     }
    
//     // ============ SIGNATURE VERIFICATION TESTS ============
    
//     function testSignatureVerification_InvalidSignature_WrongSigner() public {
//         uint256 tokenId = nft.getDoctorByAddress(doctor1);
//         bytes32 hash = _createPrescriptionHash("P1", "Med", "Dose", block.timestamp);
//         bytes memory signature = _signPrescription(hash, doctor2Key);
//         uint256 expiry = block.timestamp + 7 days;
        
//         (bool verified, string memory reason) = verifier.verifyPrescription(
//             tokenId, hash, signature, "P1", pharmacy1, expiry
//         );
        
//         assertFalse(verified);
//         assertEq(reason, "Invalid signature - fake prescription");
//     }
    
//     function testSignatureVerification_ReplayAttack() public {
//         uint256 tokenId = nft.getDoctorByAddress(doctor1);
//         bytes32 hash = _createPrescriptionHash("P1_REPLAY", "Med", "Dose", block.timestamp);
//         bytes memory signature = _signPrescription(hash, doctor1Key);
//         uint256 expiry = block.timestamp + 7 days;
        
//         vm.prank(pharmacy1);
//         verifier.submitVerifiedPrescription(
//             tokenId, hash, signature, "P1", pharmacy1, expiry
//         );
        
//         vm.prank(pharmacy2);
//         vm.expectRevert("Prescription already used");
//         verifier.submitVerifiedPrescription(
//             tokenId, hash, signature, "P1", pharmacy2, expiry
//         );
//     }
    
//     // ============ DOCTOR DAILY LIMIT TESTS ============
    
//     function testDoctorDailyLimit_Exactly30() public {
//         uint256 tokenId = nft.getDoctorByAddress(doctor1);
//         uint256 expiry = block.timestamp + 7 days;
//         uint256 day = block.timestamp / 86400;
        
//         for (uint256 i = 0; i < 30; i++) {
//             bytes32 hash = _createPrescriptionHash(
//                 string(abi.encodePacked("P", vm.toString(i))), 
//                 "Med", "Dose", block.timestamp + i
//             );
//             bytes memory signature = _signPrescription(hash, doctor1Key);
            
//             vm.prank(pharmacy1);
//             verifier.submitVerifiedPrescription(
//                 tokenId, hash, signature, string(abi.encodePacked("P", vm.toString(i))), pharmacy1, expiry
//             );
//         }
        
//         assertEq(verifier.getDoctorDailyCount(doctor1, day), 30);
        
//         bytes32 hash31 = _createPrescriptionHash("P31", "Med", "Dose", block.timestamp + 31);
//         bytes memory sig31 = _signPrescription(hash31, doctor1Key);
        
//         (bool verified, string memory reason) = verifier.verifyPrescription(
//             tokenId, hash31, sig31, "P31", pharmacy1, expiry
//         );
        
//         assertFalse(verified);
//         assertEq(reason, "Doctor exceeded 30 prescriptions today");
//     }
    
//     function testDoctorDailyLimit_ResetAfterMidnight() public {
//         uint256 tokenId = nft.getDoctorByAddress(doctor1);
//         uint256 expiry = block.timestamp + 7 days;
        
//         for (uint256 i = 0; i < 30; i++) {
//             bytes32 hash = _createPrescriptionHash(
//                 string(abi.encodePacked("P", vm.toString(i))), 
//                 "Med", "Dose", block.timestamp + i
//             );
//             bytes memory signature = _signPrescription(hash, doctor1Key);
            
//             vm.prank(pharmacy1);
//             verifier.submitVerifiedPrescription(
//                 tokenId, hash, signature, string(abi.encodePacked("P", vm.toString(i))), pharmacy1, expiry
//             );
//         }
        
//         uint256 day1 = block.timestamp / 86400;
//         assertEq(verifier.getDoctorDailyCount(doctor1, day1), 30);
        
//         // Warp to next day
//         vm.warp(block.timestamp + 86400 + 1);
//         uint256 day2 = block.timestamp / 86400;
        
//         assertTrue(day2 > day1);
//         assertEq(verifier.getDoctorDailyCount(doctor1, day2), 0);
        
//         bytes32 newHash = _createPrescriptionHash("NewDay", "Med", "Dose", block.timestamp);
//         bytes memory newSig = _signPrescription(newHash, doctor1Key);
        
//         (bool verified, ) = verifier.verifyPrescription(
//             tokenId, newHash, newSig, "NewDay", pharmacy1, expiry + 86400
//         );
        
//         assertTrue(verified);
//     }
    
//     // ============ PATIENT PHARMACY LIMIT TESTS ============
    
//     function testPatientPharmacyLimit_Exactly3Visits() public {
//         string memory patientId = "PATIENT_LIMIT_TEST";
//         uint256 tokenId = nft.getDoctorByAddress(doctor1);
//         uint256 expiry = block.timestamp + 7 days;
//         uint256 day = block.timestamp / 86400;
        
//         address[] memory pharmacies = new address[](3);
//         pharmacies[0] = pharmacy1;
//         pharmacies[1] = pharmacy2;
//         pharmacies[2] = pharmacy3;
        
//         for (uint256 i = 0; i < 3; i++) {
//             bytes32 hash = _createPrescriptionHash(
//                 string(abi.encodePacked(patientId, vm.toString(i))), 
//                 "Med", "Dose", block.timestamp + i
//             );
//             bytes memory signature = _signPrescription(hash, doctor1Key);
            
//             vm.prank(pharmacies[i]);
//             verifier.submitVerifiedPrescription(
//                 tokenId, hash, signature, patientId, pharmacies[i], expiry
//             );
//         }
        
//         assertEq(verifier.getPatientPharmacyCount(patientId, pharmacy1, day), 1);
//         assertEq(verifier.getPatientPharmacyCount(patientId, pharmacy2, day), 1);
//         assertEq(verifier.getPatientPharmacyCount(patientId, pharmacy3, day), 1);
        
//         bytes32 hash4 = _createPrescriptionHash("P4", "Med", "Dose", block.timestamp + 4);
//         bytes memory sig4 = _signPrescription(hash4, doctor1Key);
        
//         (bool verified, string memory reason) = verifier.verifyPrescription(
//             tokenId, hash4, sig4, patientId, pharmacy4, expiry
//         );
        
//         assertFalse(verified);
//         assertEq(reason, "Patient visited too many pharmacies today (max 3)");
//     }
    
//     function testPatientPharmacyLimit_SamePharmacyMultipleVisits() public {
//         string memory patientId = "SAME_PHARMACY_PATIENT";
//         uint256 tokenId = nft.getDoctorByAddress(doctor1);
//         uint256 expiry = block.timestamp + 7 days;
//         uint256 day = block.timestamp / 86400;
        
//         // Multiple visits to same pharmacy - each should count
//         for (uint256 i = 0; i < 5; i++) {
//             bytes32 hash = _createPrescriptionHash(
//                 string(abi.encodePacked(patientId, vm.toString(i))), 
//                 "Med", "Dose", block.timestamp + i
//             );
//             bytes memory signature = _signPrescription(hash, doctor1Key);
            
//             vm.prank(pharmacy1);
//             verifier.submitVerifiedPrescription(
//                 tokenId, hash, signature, patientId, pharmacy1, expiry
//             );
//         }
        
//         // Should have 5 counts for pharmacy1
//         assertEq(verifier.getPatientPharmacyCount(patientId, pharmacy1, day), 5);
        
//         // Visiting a different pharmacy should still be allowed (up to limit)
//         bytes32 newHash = _createPrescriptionHash("NEW", "Med", "Dose", block.timestamp + 100);
//         bytes memory newSig = _signPrescription(newHash, doctor1Key);
        
//         (bool verified, ) = verifier.verifyPrescription(
//             tokenId, newHash, newSig, patientId, pharmacy2, expiry
//         );
        
//         assertTrue(verified);
//     }
    
//     // ============ DOCTOR REVOCATION TESTS ============
    
//     function testDoctorRevocation_CannotRevokeTwice() public {
//         uint256 tokenId = nft.getDoctorByAddress(doctor1);
        
//         vm.startPrank(regulator);
//         nft.revokeDoctorNFT(tokenId);
        
//         // Use custom error from the Errors library
//         vm.expectRevert(bytes(Errors.ALREADY_REVOKED));
//         nft.revokeDoctorNFT(tokenId);
//         vm.stopPrank();
//     }
    
//     function testDoctorRevocation_NonRegulatorCannotRevoke() public {
//         uint256 tokenId = nft.getDoctorByAddress(doctor1);
        
//         vm.prank(doctor1);
//         vm.expectRevert(bytes(Errors.NOT_REGULATOR));
//         nft.revokeDoctorNFT(tokenId);
//     }
    
//     function testDoctorRevocation_RevokedDoctorCannotVerify() public {
//         uint256 tokenId = nft.getDoctorByAddress(doctor1);
        
//         // Submit one valid prescription
//         bytes32 hash = _createPrescriptionHash("PRE_REVOKE", "Med", "Dose", block.timestamp);
//         bytes memory signature = _signPrescription(hash, doctor1Key);
//         uint256 expiry = block.timestamp + 7 days;
        
//         vm.prank(pharmacy1);
//         verifier.submitVerifiedPrescription(
//             tokenId, hash, signature, "PRE_REVOKE", pharmacy1, expiry
//         );
        
//         // Revoke doctor
//         vm.prank(regulator);
//         nft.revokeDoctorNFT(tokenId);
        
//         // Verification should now fail
//         bytes32 newHash = _createPrescriptionHash("POST_REVOKE", "Med", "Dose", block.timestamp);
//         bytes memory newSig = _signPrescription(newHash, doctor1Key);
        
//         (bool v2, string memory reason) = verifier.verifyPrescription(
//             tokenId, newHash, newSig, "POST_REVOKE", pharmacy1, expiry
//         );
        
//         assertFalse(v2);
//         assertEq(reason, "Doctor license revoked");
//     }
    
//     // ============ EXPIRY TESTS ============
    
//     function testPrescriptionExpiry_ExactExpiryMoment() public {
//         uint256 tokenId = nft.getDoctorByAddress(doctor1);
//         bytes32 hash = _createPrescriptionHash("P1", "Med", "Dose", block.timestamp);
//         bytes memory signature = _signPrescription(hash, doctor1Key);
//         uint256 expiry = block.timestamp + 1 hours;
        
//         vm.warp(expiry);
        
//         (bool verified, string memory reason) = verifier.verifyPrescription(
//             tokenId, hash, signature, "P1", pharmacy1, expiry
//         );
        
//         // Should fail at exact expiry moment (contract uses > check)
//         assertFalse(verified);
//         assertEq(reason, "Prescription expired");
//     }
    
//     // ============ CONTRACT ADMIN TESTS ============
    
//     function testAdmin_UpdateRegulator() public {
//         address newRegulator = makeAddr("newRegulator");
        
//         // This contract is the owner
//         nft.setRegulator(newRegulator);
        
//         assertEq(nft.regulator(), newRegulator);
        
//         uint256 tokenId = nft.getDoctorByAddress(doctor1);
        
//         // Old regulator cannot revoke
//         vm.prank(regulator);
//         vm.expectRevert(bytes(Errors.NOT_REGULATOR));
//         nft.revokeDoctorNFT(tokenId);
        
//         // New regulator can revoke
//         vm.prank(newRegulator);
//         nft.revokeDoctorNFT(tokenId);
//         assertFalse(nft.isDoctorActive(tokenId));
//     }
    
//     function testAdmin_UpdateDoctorNFTInVerifier() public {
//         HealDoctorNFT newNFT = new HealDoctorNFT(regulator);
        
//         // This contract is the owner
//         verifier.setDoctorNFT(address(newNFT));
        
//         // Cannot set zero address
//         vm.expectRevert("Invalid NFT address");
//         verifier.setDoctorNFT(address(0));
//     }
    
//     // ============ NFT SOULBOUND TESTS ============
    
//     function testSoulbound_CannotTransferNFT() public {
//         uint256 tokenId = nft.getDoctorByAddress(doctor1);
        
//         vm.prank(doctor1);
//         vm.expectRevert(bytes(Errors.SOULBOUND_TRANSFER));
//         nft.transferFrom(doctor1, doctor2, tokenId);
//     }
    
//     function testSoulbound_CannotApproveTransfer() public {
//         uint256 tokenId = nft.getDoctorByAddress(doctor1);
        
//         vm.prank(doctor1);
//         nft.approve(doctor2, tokenId);
        
//         assertEq(nft.getApproved(tokenId), doctor2);
        
//         vm.prank(doctor2);
//         vm.expectRevert(bytes(Errors.SOULBOUND_TRANSFER));
//         nft.transferFrom(doctor1, doctor2, tokenId);
//     }
    
//     // ============ INVARIANT TESTS ============
    
//     function testInvariant_DoctorAlwaysHasOnlyOneNFT() public {
//         assertEq(nft.balanceOf(doctor1), 1);
//         assertEq(nft.balanceOf(doctor2), 1);
//         assertEq(nft.balanceOf(doctor3), 1);
        
//         HealTypes.DoctorRegistration memory reg = HealTypes.DoctorRegistration({
//             licenseNumber: "LIC999",
//             fullName: "Dr. Extra",
//             specialty: "Extra"
//         });
        
//         vm.prank(regulator);
//         vm.expectRevert(bytes(Errors.DOCTOR_ALREADY_REGISTERED));
//         nft.mintDoctorNFT(doctor1, reg);
//     }
// }