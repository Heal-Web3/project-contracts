// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/HealPrescriptionVerifier.sol";
import "./mocks/MockDoctorNFT.sol";
import "../src/HealTypes.sol";

contract HealPrescriptionVerifierTest is Test {
    HealPrescriptionVerifier public verifier;
    MockDoctorNFT public mockNFT;

    // Test addresses
    address public doctor = address(0x1);
    address public pharmacy = address(0x2);
    address public pharmacy2 = address(0x3);
    address public owner = address(0x4);
    address public regulator = address(0x5);

    // Doctor private key for signing
    uint256 public doctorPrivateKey = 0x123456789;
    address public doctorWithKey;

    uint256 public doctorTokenId;

    // Event declarations for testing
    event PrescriptionSubmitted(
        uint256 indexed doctorNFTId,
        string patientId,
        address indexed pharmacy,
        bytes32 prescriptionHash,
        uint256 timestamp
    );

    event PrescriptionVerified(
        uint256 indexed doctorNFTId,
        string patientId,
        address indexed pharmacy,
        bool verified,
        string reason,
        uint256 timestamp
    );

    event DoctorNFTContractUpdated(address indexed oldContract, address indexed newContract, address updatedBy);

    // ============ SETUP ============

    function setUp() public {
        // Create doctor address from private key
        doctorWithKey = vm.addr(doctorPrivateKey);

        vm.prank(owner);
        mockNFT = new MockDoctorNFT();

        // Mint NFT for doctor
        doctorTokenId = mockNFT.mintDoctor(doctorWithKey, "LIC12345", "Dr. Jane Smith", "Cardiology");

        vm.prank(owner);
        verifier = new HealPrescriptionVerifier(address(mockNFT));

        // Label addresses for better trace output
        vm.label(doctorWithKey, "Doctor");
        vm.label(pharmacy, "Pharmacy");
        vm.label(pharmacy2, "Pharmacy2");
        vm.label(owner, "Owner");
        vm.label(regulator, "Regulator");
    }

    // ============ HELPER FUNCTIONS ============

    function _createPrescriptionHash(
        string memory patientId,
        string memory medicine,
        string memory dosage,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(patientId, medicine, dosage, timestamp));
    }

    function _signPrescription(bytes32 hash, uint256 privateKey) internal pure returns (bytes memory) {
        bytes32 ethSignedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethSignedHash);
        return abi.encodePacked(r, s, v);
    }

    function _createValidPrescription(string memory patientId)
        internal
        view
        returns (bytes32 hash, bytes memory signature, uint256 expiry)
    {
        hash = _createPrescriptionHash(patientId, "Amoxicillin", "500mg twice daily", block.timestamp);
        signature = _signPrescription(hash, doctorPrivateKey);
        expiry = block.timestamp + 7 days;
    }

    // ============ TEST 1: VALID PRESCRIPTION ============

    function testValidPrescription() public {
        string memory patientId = "P12345";
        (bytes32 hash, bytes memory signature, uint256 expiry) = _createValidPrescription(patientId);

        (bool verified, string memory reason) =
            verifier.verifyPrescription(doctorTokenId, hash, signature, patientId, pharmacy, expiry);

        assertTrue(verified, "Prescription should be valid");
        assertEq(reason, "", "Reason should be empty");
    }

    function testValidPrescriptionSubmit() public {
        string memory patientId = "P12345";
        (bytes32 hash, bytes memory signature, uint256 expiry) = _createValidPrescription(patientId);

        vm.prank(pharmacy);
        bool success = verifier.submitVerifiedPrescription(doctorTokenId, hash, signature, patientId, pharmacy, expiry);

        assertTrue(success, "Submit should succeed");

        // Verify counters were updated
        uint256 day = block.timestamp / 86400;
        assertEq(verifier.getDoctorDailyCount(doctorWithKey, day), 1);
        assertEq(verifier.getPatientPharmacyCount(patientId, pharmacy, day), 1);
        assertTrue(verifier.isPrescriptionUsed(hash));
    }

    // ============ TEST 2: EXPIRED PRESCRIPTION ============

    function testExpiredPrescription() public {
        string memory patientId = "P12345";
        bytes32 hash = _createPrescriptionHash(patientId, "Medicine", "Dosage", block.timestamp);
        bytes memory signature = _signPrescription(hash, doctorPrivateKey);
        uint256 expiry = block.timestamp - 1; // Already expired

        (bool verified, string memory reason) =
            verifier.verifyPrescription(doctorTokenId, hash, signature, patientId, pharmacy, expiry);

        assertFalse(verified, "Expired prescription should fail");
        assertEq(reason, "Prescription expired");
    }

    function testExpiredPrescriptionSubmitReverts() public {
        string memory patientId = "P12345";
        bytes32 hash = _createPrescriptionHash(patientId, "Medicine", "Dosage", block.timestamp);
        bytes memory signature = _signPrescription(hash, doctorPrivateKey);
        uint256 expiry = block.timestamp - 1;

        vm.prank(pharmacy);
        vm.expectRevert("Prescription expired");
        verifier.submitVerifiedPrescription(doctorTokenId, hash, signature, patientId, pharmacy, expiry);
    }

    // ============ TEST 3: INVALID SIGNATURE ============

    function testInvalidSignature() public {
        string memory patientId = "P12345";
        bytes32 hash = _createPrescriptionHash(patientId, "Medicine", "Dosage", block.timestamp);

        // Sign with wrong key
        uint256 wrongKey = 0x99999;
        bytes memory signature = _signPrescription(hash, wrongKey);
        uint256 expiry = block.timestamp + 7 days;

        (bool verified, string memory reason) =
            verifier.verifyPrescription(doctorTokenId, hash, signature, patientId, pharmacy, expiry);

        assertFalse(verified, "Invalid signature should fail");
        assertEq(reason, "Invalid signature - fake prescription");
    }

    function testTamperedPrescriptionHash() public {
        string memory patientId = "P12345";
        bytes32 originalHash = _createPrescriptionHash(patientId, "Amoxicillin", "500mg", block.timestamp);
        bytes memory signature = _signPrescription(originalHash, doctorPrivateKey);

        // Tamper with the hash
        bytes32 tamperedHash = _createPrescriptionHash(patientId, "Oxycontin", "100mg", block.timestamp);
        uint256 expiry = block.timestamp + 7 days;

        (bool verified, string memory reason) =
            verifier.verifyPrescription(doctorTokenId, tamperedHash, signature, patientId, pharmacy, expiry);

        assertFalse(verified, "Tampered prescription should fail");
        assertEq(reason, "Invalid signature - fake prescription");
    }

    // ============ TEST 4: REVOKED DOCTOR ============

    function testRevokedDoctor() public {
        // Revoke doctor's license
        mockNFT.setActive(doctorTokenId, false);

        string memory patientId = "P12345";
        (bytes32 hash, bytes memory signature, uint256 expiry) = _createValidPrescription(patientId);

        (bool verified, string memory reason) =
            verifier.verifyPrescription(doctorTokenId, hash, signature, patientId, pharmacy, expiry);

        assertFalse(verified, "Revoked doctor should fail");
        assertEq(reason, "Doctor license revoked");
    }

    // ============ TEST 5: DOCTOR DAILY LIMIT ============

    function testDoctorDailyLimit() public {
        // Submit 30 prescriptions (max allowed)
        for (uint256 i = 0; i < 30; i++) {
            string memory loopPatientId = string(abi.encodePacked("P", vm.toString(i)));
            (bytes32 loopHash, bytes memory loopSig, uint256 loopExpiry) = _createValidPrescription(loopPatientId);

            vm.prank(pharmacy);
            verifier.submitVerifiedPrescription(doctorTokenId, loopHash, loopSig, loopPatientId, pharmacy, loopExpiry);
        }

        // 31st should fail
        string memory patientId31 = "P31";
        (bytes32 hash31, bytes memory sig31, uint256 expiry31) = _createValidPrescription(patientId31);

        (bool verified, string memory reason) =
            verifier.verifyPrescription(doctorTokenId, hash31, sig31, patientId31, pharmacy, expiry31);

        assertFalse(verified, "Should exceed daily limit");
        assertEq(reason, "Doctor exceeded 30 prescriptions today");
    }

    function testDoctorDailyLimitSubmitReverts() public {
        // Submit 30 prescriptions
        for (uint256 i = 0; i < 30; i++) {
            string memory loopPatientId = string(abi.encodePacked("P", vm.toString(i)));
            (bytes32 loopHash, bytes memory loopSig, uint256 loopExpiry) = _createValidPrescription(loopPatientId);

            vm.prank(pharmacy);
            verifier.submitVerifiedPrescription(doctorTokenId, loopHash, loopSig, loopPatientId, pharmacy, loopExpiry);
        }

        // 31st should revert
        string memory patientId31 = "P31";
        (bytes32 hash31, bytes memory sig31, uint256 expiry31) = _createValidPrescription(patientId31);

        vm.prank(pharmacy);
        vm.expectRevert("Doctor exceeded 30 prescriptions today");
        verifier.submitVerifiedPrescription(doctorTokenId, hash31, sig31, patientId31, pharmacy, expiry31);
    }

    // ============ TEST 6: PATIENT PHARMACY LIMIT ============

    function testPatientPharmacyLimit() public {
        string memory patientId = "P12345";

        // Submit 3 prescriptions for same patient to same pharmacy
        for (uint256 i = 0; i < 3; i++) {
            bytes32 loopHash = _createPrescriptionHash(patientId, "Medicine", "Dosage", block.timestamp + i);
            bytes memory loopSig = _signPrescription(loopHash, doctorPrivateKey);
            uint256 loopExpiry = block.timestamp + 7 days;

            vm.prank(pharmacy);
            verifier.submitVerifiedPrescription(doctorTokenId, loopHash, loopSig, patientId, pharmacy, loopExpiry);
        }

        // 4th should fail
        bytes32 hash4 = _createPrescriptionHash(patientId, "Medicine", "Dosage", block.timestamp + 100);
        bytes memory sig4 = _signPrescription(hash4, doctorPrivateKey);
        uint256 expiry4 = block.timestamp + 7 days;

        (bool verified, string memory reason) =
            verifier.verifyPrescription(doctorTokenId, hash4, sig4, patientId, pharmacy, expiry4);

        assertFalse(verified, "Should exceed pharmacy visit limit");
        assertEq(reason, "Patient visited too many pharmacies today (max 3)");
    }

    function testPatientDifferentPharmacies() public {
        string memory patientId = "P12345";

        // Create FIRST prescription (different timestamp makes different hash)
        bytes32 hash1 = _createPrescriptionHash(patientId, "Amoxicillin", "500mg", block.timestamp);
        bytes memory sig1 = _signPrescription(hash1, doctorPrivateKey);
        uint256 expiry1 = block.timestamp + 7 days;

        // Visit pharmacy 1 with first prescription
        vm.prank(pharmacy);
        verifier.submitVerifiedPrescription(doctorTokenId, hash1, sig1, patientId, pharmacy, expiry1);

        // Create SECOND prescription (different medicine or timestamp)
        bytes32 hash2 = _createPrescriptionHash(patientId, "Ibuprofen", "400mg", block.timestamp + 1);
        bytes memory sig2 = _signPrescription(hash2, doctorPrivateKey);
        uint256 expiry2 = block.timestamp + 7 days;

        // Visit pharmacy 2 with second prescription - should be allowed (different pharmacy)
        vm.prank(pharmacy2);
        verifier.submitVerifiedPrescription(doctorTokenId, hash2, sig2, patientId, pharmacy2, expiry2);

        uint256 day = block.timestamp / 86400;
        assertEq(verifier.getPatientPharmacyCount(patientId, pharmacy, day), 1);
        assertEq(verifier.getPatientPharmacyCount(patientId, pharmacy2, day), 1);
    }

    // ============ TEST 7: DAILY RESET ============


    function testDailyReset() public {
    string memory patientId = "P12345";
    
    // Set a specific timestamp
    uint256 startTime = 1641024000; // Jan 1, 2022 00:00:00 UTC
    vm.warp(startTime);
    
    // Submit prescription on day 1
    (bytes32 hash, bytes memory signature, uint256 expiry) = _createValidPrescription(patientId);
    vm.prank(pharmacy);
    verifier.submitVerifiedPrescription(doctorTokenId, hash, signature, patientId, pharmacy, expiry);
    
    // Calculate day keys
    uint256 day1 = startTime / 86400;
    assertEq(verifier.getDoctorDailyCount(doctorWithKey, day1), 1);
    
    // Move to next day (add 86401 seconds to ensure we cross the boundary)
    uint256 newTime = startTime + 86401; // Add 1 extra second
    vm.warp(newTime);
    
    // Recalculate day key
    uint256 day2 = newTime / 86400;
    
    // Verify we're in a different day
    console.log("Day1:", day1);
    console.log("Day2:", day2);
    assertTrue(day2 > day1, "Day2 should be greater than Day1");
    
    // Check counter for new day - should be 0
    uint256 day2Count = verifier.getDoctorDailyCount(doctorWithKey, day2);
    assertEq(day2Count, 0, "Counter should be 0 for the new day");
    
    // Submit on day 2
    (bytes32 hash2, bytes memory signature2, uint256 expiry2) = _createValidPrescription("P67890");
    vm.prank(pharmacy);
    verifier.submitVerifiedPrescription(doctorTokenId, hash2, signature2, "P67890", pharmacy, expiry2);
    
    // Verify day 2 count increased
    assertEq(verifier.getDoctorDailyCount(doctorWithKey, day2), 1);
    
    // Verify day 1 count unchanged
    assertEq(verifier.getDoctorDailyCount(doctorWithKey, day1), 1);
}
    



    // ============ TEST 8: REPLAY PROTECTION ============

    function testReplayProtection() public {
        string memory patientId = "P12345";
        (bytes32 hash, bytes memory signature, uint256 expiry) = _createValidPrescription(patientId);

        // First submission works
        vm.prank(pharmacy);
        verifier.submitVerifiedPrescription(doctorTokenId, hash, signature, patientId, pharmacy, expiry);

        // Second submission with same hash should fail
        vm.prank(pharmacy);
        vm.expectRevert("Prescription already used");
        verifier.submitVerifiedPrescription(doctorTokenId, hash, signature, patientId, pharmacy, expiry);
    }

    // ============ TEST 9: DOCTOR NOT REGISTERED ============

    function testDoctorNotRegistered() public {
        uint256 nonExistentTokenId = 999;
        string memory patientId = "P12345";
        (bytes32 hash, bytes memory signature, uint256 expiry) = _createValidPrescription(patientId);

        (bool verified, string memory reason) =
            verifier.verifyPrescription(nonExistentTokenId, hash, signature, patientId, pharmacy, expiry);

        assertFalse(verified);
        assertEq(reason, "Doctor not registered");
    }

    // ============ TEST 10: SIGNATURE RECOVERY ============

    function testSignatureRecovery() public {
        string memory patientId = "P12345";
        bytes32 hash = _createPrescriptionHash(patientId, "Medicine", "Dosage", block.timestamp);
        bytes memory signature = _signPrescription(hash, doctorPrivateKey);

        // Verify the recovered signer matches doctor
        bytes32 ethSignedHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash));
        address recovered = recoverSigner(ethSignedHash, signature);

        assertEq(recovered, doctorWithKey, "Recovered signer should match doctor");
    }

    function recoverSigner(bytes32 ethSignedHash, bytes memory signature) internal pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);
        return ecrecover(ethSignedHash, v, r, s);
    }

    function splitSignature(bytes memory sig) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "Invalid signature length");
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
        if (v < 27) v += 27;
    }

    // ============ TEST 11: VIEW FUNCTIONS ============

    function testGetDoctorTodayCount() public {
        // Initially 0
        assertEq(verifier.getDoctorTodayCount(doctorWithKey), 0);

        // Submit one prescription
        string memory patientId = "P12345";
        (bytes32 hash, bytes memory signature, uint256 expiry) = _createValidPrescription(patientId);

        vm.prank(pharmacy);
        verifier.submitVerifiedPrescription(doctorTokenId, hash, signature, patientId, pharmacy, expiry);

        assertEq(verifier.getDoctorTodayCount(doctorWithKey), 1);
    }

    function testGetPatientPharmacyTodayCount() public {
        string memory patientId = "P12345";

        assertEq(verifier.getPatientPharmacyTodayCount(patientId, pharmacy), 0);

        (bytes32 hash, bytes memory signature, uint256 expiry) = _createValidPrescription(patientId);

        vm.prank(pharmacy);
        verifier.submitVerifiedPrescription(doctorTokenId, hash, signature, patientId, pharmacy, expiry);

        assertEq(verifier.getPatientPharmacyTodayCount(patientId, pharmacy), 1);
    }

    // ============ TEST 12: ADMIN FUNCTIONS ============

    function testSetDoctorNFT() public {
        address newNFT = address(0x999);

        vm.prank(owner);
        verifier.setDoctorNFT(newNFT);

        assertEq(address(verifier.doctorNFT()), newNFT);
    }

    function testSetDoctorNFTRevertsNonOwner() public {
        address newNFT = address(0x999);

        vm.prank(pharmacy);
        vm.expectRevert();
        verifier.setDoctorNFT(newNFT);
    }

    function testSetDoctorNFTRevertsZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("Invalid NFT address");
        verifier.setDoctorNFT(address(0));
    }

    // ============ TEST 13: FUZZ TESTING ============

    function testFuzz_ValidPrescription(string memory patientId, string memory medicine, string memory dosage) public {
        vm.assume(bytes(patientId).length > 0);
        vm.assume(bytes(medicine).length > 0);
        vm.assume(bytes(dosage).length > 0);

        bytes32 hash = _createPrescriptionHash(patientId, medicine, dosage, block.timestamp);
        bytes memory signature = _signPrescription(hash, doctorPrivateKey);
        uint256 expiry = block.timestamp + 7 days;

        (bool verified, string memory reason) =
            verifier.verifyPrescription(doctorTokenId, hash, signature, patientId, pharmacy, expiry);

        assertTrue(verified, reason);
    }

    function testFuzz_InvalidExpiry(uint256 expiry) public {
        vm.assume(expiry < block.timestamp);

        string memory patientId = "P12345";
        bytes32 hash = _createPrescriptionHash(patientId, "Medicine", "Dosage", block.timestamp);
        bytes memory signature = _signPrescription(hash, doctorPrivateKey);

        (bool verified, string memory reason) =
            verifier.verifyPrescription(doctorTokenId, hash, signature, patientId, pharmacy, expiry);

        assertFalse(verified);
        assertEq(reason, "Prescription expired");
    }

    // ============ TEST 14: EVENT EMISSIONS ============

    function testSubmitEmitsEvents() public {
        string memory patientId = "P12345";
        (bytes32 hash, bytes memory signature, uint256 expiry) = _createValidPrescription(patientId);

        // First event: PrescriptionVerified
        vm.expectEmit(true, true, true, true);
        emit PrescriptionVerified(doctorTokenId, patientId, pharmacy, true, "", block.timestamp);

        // Second event: PrescriptionSubmitted
        vm.expectEmit(true, true, true, true);
        emit PrescriptionSubmitted(doctorTokenId, patientId, pharmacy, hash, block.timestamp);

        vm.prank(pharmacy);
        verifier.submitVerifiedPrescription(doctorTokenId, hash, signature, patientId, pharmacy, expiry);
    }

    function testSetDoctorNFTEmitsEvent() public {
        address newNFT = address(0x999);

        vm.expectEmit(true, true, true, true);
        emit DoctorNFTContractUpdated(address(mockNFT), newNFT, owner);

        vm.prank(owner);
        verifier.setDoctorNFT(newNFT);
    }

    function testVerifyPrescriptionEmitsEvent() public {
        string memory patientId = "P12345";
        (bytes32 hash, bytes memory signature, uint256 expiry) = _createValidPrescription(patientId);

        // Expect the PrescriptionVerified event
        vm.expectEmit(true, true, true, true);
        emit PrescriptionVerified(doctorTokenId, patientId, pharmacy, true, "", block.timestamp);

        // Call verifyPrescription (view function)
        (bool verified, ) =
            verifier.verifyPrescription(doctorTokenId, hash, signature, patientId, pharmacy, expiry);
        
        assertTrue(verified);
    }
}
