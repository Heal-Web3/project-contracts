// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {HealDoctorNFT} from "../src/HealDoctorNFT.sol";
import {HealTypes} from "../src/HealTypes.sol";
import {Errors} from "../src/HealTypes.sol";

contract HealDoctorNFTTest is Test {
    HealDoctorNFT public nft;
    
    address public admin = address(1);
    address public regulator = address(2);
    address public doctor = address(3);
    address public hacker = address(4);

    function setUp() public {
        // Deploy as admin, set regulator
        vm.prank(admin);
        nft = new HealDoctorNFT(regulator);
    }

    // 1. testMintNFT
    function testMintNFT() public {
        HealTypes.DoctorRegistration memory reg = HealTypes.DoctorRegistration({
            licenseNumber: "MD12345",
            fullName: "Dr. Gregory House",
            specialty: "Diagnostics"
        });

        vm.prank(regulator);
        uint256 tokenId = nft.mintDoctorNFT(doctor, reg);

        assertEq(nft.ownerOf(tokenId), doctor);
        assertEq(nft.isDoctorActive(tokenId), true);
    }

    // 2. testCannotTransfer (Soulbound)
    function testCannotTransfer() public {
        // First, mint the NFT
        testMintNFT();
        uint256 tokenId = nft.getDoctorByAddress(doctor);

        // Try to transfer from doctor to hacker
        vm.prank(doctor);
        vm.expectRevert(bytes(Errors.SOULBOUND_TRANSFER));
        nft.transferFrom(doctor, hacker, tokenId);
    }

    // 3. testOnlyRegulatorCanRevoke
    function testOnlyRegulatorCanRevoke() public {
        testMintNFT();
        uint256 tokenId = nft.getDoctorByAddress(doctor);

        vm.prank(hacker);
        vm.expectRevert(bytes(Errors.NOT_REGULATOR));
        nft.revokeDoctorNFT(tokenId);
    }

    // 4. testRevokeNFT
    function testRevokeNFT() public {
        testMintNFT();
        uint256 tokenId = nft.getDoctorByAddress(doctor);

        vm.prank(regulator);
        nft.revokeDoctorNFT(tokenId);

        assertEq(nft.isDoctorActive(tokenId), false);
    }

    // 5. testDoubleMintPrevented
    function testDoubleMintPrevented() public {
        testMintNFT();
        
        HealTypes.DoctorRegistration memory reg = HealTypes.DoctorRegistration({
            licenseNumber: "MD-DUP",
            fullName: "Duplicate Doc",
            specialty: "General"
        });

        vm.prank(regulator);
        vm.expectRevert(bytes(Errors.DOCTOR_ALREADY_REGISTERED));
        nft.mintDoctorNFT(doctor, reg);
    }

    // 6. testGetDoctorInfo
    function testGetDoctorInfo() public {
        testMintNFT();
        uint256 tokenId = nft.getDoctorByAddress(doctor);

        HealTypes.Doctor memory info = nft.getDoctorInfo(tokenId);
        assertEq(info.licenseNumber, "MD12345");
        assertEq(info.fullName, "Dr. Gregory House");
    }

    // 7. testGetDoctorByAddress
    function testGetDoctorByAddress() public {
        testMintNFT();
        uint256 tokenId = nft.getDoctorByAddress(doctor);
        assertEq(tokenId, 1);
    }

    // 8. testSetRegulator
    function testSetRegulator() public {
        address newRegulator = address(99);
        
        vm.prank(admin);
        nft.setRegulator(newRegulator);

        assertEq(nft.regulator(), newRegulator);
    }
}