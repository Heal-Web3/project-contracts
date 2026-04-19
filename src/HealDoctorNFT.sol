// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {HealTypes} from "./HealTypes.sol";
import {Errors} from "./HealTypes.sol";
import {Events} from "./HealTypes.sol";

/**
 * @title HealDoctorNFT
 * @author Developer 1
 * @notice Manages doctor identity through Soulbound NFTs.
 * @dev Implements registration, revocation, and soulbound transfer restrictions.
 */
contract HealDoctorNFT is ERC721, Ownable {
    
    // Counter for doctor IDs
    uint256 private _nextTokenId;
    
    // The regulator address (Health Authority) authorized to mint/revoke
    address public regulator;

    // Mapping from Token ID to Doctor metadata
    mapping(uint256 => HealTypes.Doctor) private _doctorInfo;
    
    // Mapping to ensure an address only holds one NFT
    mapping(address => uint256) private _addressToTokenId;
    mapping(address => bool) private _hasNFT;

    /**
     * @dev Access control for the regulator
     */
    modifier onlyRegulator() {
        if (msg.sender != regulator) revert(Errors.NOT_REGULATOR);
        _;
    }

    /**
     * @param _initialRegulator The address of the medical board/authority
     */
    constructor(address _initialRegulator) 
        ERC721("Heal Doctor ID", "HEAL-DR") 
        Ownable(msg.sender) 
    {
        if (_initialRegulator == address(0)) revert(Errors.INVALID_ADDRESS);
        regulator = _initialRegulator;
    }

    /**
     * @notice Mints a Soulbound NFT to a doctor. Only callable by Regulator.
     * @param _doctor The wallet address of the doctor
     * @param _reg Registration data (License, Name, Specialty)
     */
    function mintDoctorNFT(address _doctor, HealTypes.DoctorRegistration calldata _reg) 
        external 
        onlyRegulator 
        returns (uint256) 
    {
        // 1. Validations
        if (_hasNFT[_doctor]) revert(Errors.DOCTOR_ALREADY_REGISTERED);
        if (bytes(_reg.licenseNumber).length == 0) revert(Errors.LICENSE_REQUIRED);
        if (bytes(_reg.fullName).length == 0) revert(Errors.NAME_REQUIRED);

        // 2. State Updates
        uint256 tokenId = ++_nextTokenId;
        _hasNFT[_doctor] = true;
        _addressToTokenId[_doctor] = tokenId;

        _doctorInfo[tokenId] = HealTypes.Doctor({
            licenseNumber: _reg.licenseNumber,
            fullName: _reg.fullName,
            specialty: _reg.specialty,
            registeredAt: block.timestamp,
            isActive: true
        });

        // 3. Mint NFT
        _safeMint(_doctor, tokenId);

        // 4. Emit Event for indexing
        emit Events.DoctorMinted(
            tokenId, 
            _doctor, 
            _reg.licenseNumber, 
            _reg.fullName, 
            _reg.specialty, 
            block.timestamp
        );

        return tokenId;
    }

    /**
     * @notice Deactivates a doctor's credential. Only callable by Regulator.
     * @param _tokenId The ID of the doctor's NFT
     */
    function revokeDoctorNFT(uint256 _tokenId) external onlyRegulator {
        // Validation: Use _ownerOf to check existence in OZ v5.0+
        if (_ownerOf(_tokenId) == address(0)) revert(Errors.TOKEN_DOES_NOT_EXIST);
        if (!_doctorInfo[_tokenId].isActive) revert(Errors.ALREADY_REVOKED);

        _doctorInfo[_tokenId].isActive = false;

        emit Events.DoctorRevoked(_tokenId, ownerOf(_tokenId), msg.sender, block.timestamp);
    }

    // --- View Functions ---

    /**
     * @notice Returns doctor metadata for a given token ID
     */
    function getDoctorInfo(uint256 _tokenId) external view returns (HealTypes.Doctor memory) {
        if (_ownerOf(_tokenId) == address(0)) revert(Errors.TOKEN_DOES_NOT_EXIST);
        return _doctorInfo[_tokenId];
    }

    /**
     * @notice Checks if a doctor is currently authorized to issue prescriptions
     */
    function isDoctorActive(uint256 _tokenId) external view returns (bool) {
        return _ownerOf(_tokenId) != address(0) && _doctorInfo[_tokenId].isActive;
    }

    /**
     * @notice Finds a doctor's Token ID based on their wallet address
     */
    function getDoctorByAddress(address _doctor) external view returns (uint256) {
        if (!_hasNFT[_doctor]) revert(Errors.TOKEN_DOES_NOT_EXIST);
        return _addressToTokenId[_doctor];
    }

    // --- Soulbound Transfer Overrides ---

    /**
     * @dev Overriding transfer functions to revert and make the NFT Soulbound.
     * Doctors should not be able to "sell" or "transfer" their license.
     */
    function transferFrom(address /*from*/, address /*to*/, uint256 /*tokenId*/) public override {
        revert(Errors.SOULBOUND_TRANSFER);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override {
        revert(Errors.SOULBOUND_TRANSFER);
    }

    // --- Admin Functions ---

    /**
     * @notice Allows the contract owner to change the regulator address
     */
    function setRegulator(address _newRegulator) external onlyOwner {
        if (_newRegulator == address(0)) revert(Errors.INVALID_ADDRESS);
        address old = regulator;
        regulator = _newRegulator;
        emit Events.RegulatorUpdated(old, _newRegulator, msg.sender);
    }
}