// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../src/HealTypes.sol";

/**
 * @title MockDoctorNFT
 * @dev Mock contract for testing HealPrescriptionVerifier in isolation
 * @notice Person 2: Use this until Person 1's contract is ready
 */
contract MockDoctorNFT {
    mapping(uint256 => address) private _owners;
    mapping(uint256 => bool) private _active;
    mapping(address => uint256) private _doctorToTokenId;
    mapping(uint256 => HealTypes.Doctor) private _doctors;

    uint256 private _nextTokenId = 1;
    address public regulator;

    constructor() {
        regulator = msg.sender;
    }

    // ============ MOCK SETUP FUNCTIONS ============

    function mintDoctor(address doctor, string memory licenseNumber, string memory fullName, string memory specialty)
        external
        returns (uint256)
    {
        uint256 tokenId = _nextTokenId++;
        _owners[tokenId] = doctor;
        _active[tokenId] = true;
        _doctorToTokenId[doctor] = tokenId;
        _doctors[tokenId] = HealTypes.Doctor({
            licenseNumber: licenseNumber,
            fullName: fullName,
            specialty: specialty,
            registeredAt: block.timestamp,
            isActive: true
        });
        return tokenId;
    }

    function setActive(uint256 tokenId, bool active) external {
        _active[tokenId] = active;
        _doctors[tokenId].isActive = active;
    }

    function setRegulator(address newRegulator) external {
        regulator = newRegulator;
    }

    // ============ IHealDoctorNFT INTERFACE ============

    function ownerOf(uint256 tokenId) external view returns (address) {
        require(_owners[tokenId] != address(0), "Token does not exist");
        return _owners[tokenId];
    }

    function isDoctorActive(uint256 tokenId) external view returns (bool) {
        require(_owners[tokenId] != address(0), "Token does not exist");
        return _active[tokenId];
    }

    function getDoctorInfo(uint256 tokenId) external view returns (HealTypes.Doctor memory) {
        require(_owners[tokenId] != address(0), "Token does not exist");
        return _doctors[tokenId];
    }

    function getDoctorByAddress(address doctor) external view returns (uint256) {
        uint256 tokenId = _doctorToTokenId[doctor];
        require(tokenId != 0, "Doctor not registered");
        return tokenId;
    }

    // ============ HELPER FUNCTIONS ============

    function getTokenId(address doctor) external view returns (uint256) {
        return _doctorToTokenId[doctor];
    }
}
