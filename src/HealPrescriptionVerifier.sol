// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "./HealTypes.sol";

/**
 * @title HealPrescriptionVerifier
 * @dev Verifies prescription signatures and enforces fraud detection rules
 * @notice All verification logic runs on-chain with daily counters
 * @dev Person 2: [Your Name]
 */
contract HealPrescriptionVerifier is Ownable {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    // ============ STATE VARIABLES ============

    /// @notice Reference to the Doctor NFT contract
    IHealDoctorNFT public doctorNFT;

    /// @notice Maximum prescriptions per doctor per day
    uint256 public constant MAX_PRESCRIPTIONS_PER_DAY = 30;

    /// @notice Maximum pharmacies a patient can visit per day
    uint256 public constant MAX_PHARMACIES_PER_PATIENT = 3;

    /// @notice Seconds in a day for timestamp calculations
    uint256 public constant SECONDS_PER_DAY = 86400;

    /// @dev doctor address => day key => count
    mapping(address => mapping(uint256 => uint256)) public doctorDailyCount;

    /// @dev patient ID => pharmacy address => day key => count
    mapping(string => mapping(address => mapping(uint256 => uint256))) public patientPharmacyCount;

    /// @notice Tracks if a prescription hash has been used (replay protection)
    mapping(bytes32 => bool) public usedPrescriptions;

    // ============ EVENTS ============

    event PrescriptionVerified(
        uint256 indexed doctorNFTId,
        string patientId,
        address indexed pharmacy,
        bool verified,
        string reason,
        uint256 timestamp
    );

    event PrescriptionSubmitted(
        uint256 indexed doctorNFTId,
        string patientId,
        address indexed pharmacy,
        bytes32 prescriptionHash,
        uint256 timestamp
    );

    event DailyCountersReset(uint256 dayKey, uint256 resetAt);

    event DoctorNFTContractUpdated(address indexed oldContract, address indexed newContract, address updatedBy);

    // ============ CONSTRUCTOR ============

    /**
     * @dev Initializes the verifier with Doctor NFT contract address
     * @param _doctorNFT Address of the HealDoctorNFT contract
     */
    constructor(address _doctorNFT) Ownable(msg.sender) {
        require(_doctorNFT != address(0), "Invalid NFT address");
        doctorNFT = IHealDoctorNFT(_doctorNFT);
    }

    // ============ EXTERNAL FUNCTIONS ============

    /**
     * @dev Verifies a prescription without state changes (view-only, 0 gas)
     * @param doctorNFTId Doctor's NFT token ID
     * @param prescriptionHash Keccak256 hash of prescription data
     * @param signature Doctor's signature of the hash
     * @param patientId Unique patient identifier
     * @param pharmacyAddress Address of the pharmacy verifying
     * @param expiry Unix timestamp when prescription expires
     * @return verified True if prescription passes all checks
     * @return reason Human-readable success/failure message
     */
    function verifyPrescription(
        uint256 doctorNFTId,
        bytes32 prescriptionHash,
        bytes memory signature,
        string memory patientId,
        address pharmacyAddress,
        uint256 expiry
    ) public returns (bool verified, string memory reason) {
        // Check 1: Doctor NFT exists and is active
        try doctorNFT.ownerOf(doctorNFTId) returns (address doctorAddress) {
            if (!doctorNFT.isDoctorActive(doctorNFTId)) {
                return (false, "Doctor license revoked");
            }

            // Check 2: Prescription not expired
            if (block.timestamp > expiry) {
                return (false, "Prescription expired");
            }

            // Check 3: Verify signature matches doctor
            bytes32 ethSignedMessageHash = prescriptionHash.toEthSignedMessageHash();
            address signer = ethSignedMessageHash.recover(signature);
            if (signer != doctorAddress) {
                return (false, "Invalid signature - fake prescription");
            }

            // Check 4: Doctor daily limit (≤ 30 prescriptions/day)
            uint256 day = _getCurrentDayKey();
            if (doctorDailyCount[doctorAddress][day] >= MAX_PRESCRIPTIONS_PER_DAY) {
                return (false, "Doctor exceeded 30 prescriptions today");
            }

            // Check 5: Patient pharmacy visit limit (≤ 3 pharmacies/day)
            if (patientPharmacyCount[patientId][pharmacyAddress][day] >= MAX_PHARMACIES_PER_PATIENT) {
                return (false, "Patient visited too many pharmacies today (max 3)");
            }

            // Emit verification success event (works in view calls too)
            emit PrescriptionVerified(
                doctorNFTId,
                patientId,
                pharmacyAddress,
                true,
                "",
                block.timestamp
            );

            return (true, "");
        } catch {
            return (false, "Doctor not registered");
        }
    }

    /**
     * @dev Submits verified prescription and updates counters (requires gas)
     * @param doctorNFTId Doctor's NFT token ID
     * @param prescriptionHash Keccak256 hash of prescription data
     * @param signature Doctor's signature
     * @param patientId Unique patient identifier
     * @param pharmacyAddress Pharmacy address (usually msg.sender)
     * @param expiry Prescription expiration timestamp
     * @return success True if submission succeeded
     */
    function submitVerifiedPrescription(
        uint256 doctorNFTId,
        bytes32 prescriptionHash,
        bytes memory signature,
        string memory patientId,
        address pharmacyAddress,
        uint256 expiry
    ) external returns (bool) {
        // Verify prescription first
        (bool verified, string memory reason) =
            verifyPrescription(doctorNFTId, prescriptionHash, signature, patientId, pharmacyAddress, expiry);

        require(verified, reason);

        emit PrescriptionVerified(
            doctorNFTId,
            patientId,
            pharmacyAddress,
            true,
            "",
            block.timestamp
        );

        // Replay protection - ensure prescription hasn't been used
        require(!usedPrescriptions[prescriptionHash], "Prescription already used");

        // Get doctor address for counter update
        address doctorAddress = doctorNFT.ownerOf(doctorNFTId);
        uint256 day = _getCurrentDayKey();

        // Update state
        doctorDailyCount[doctorAddress][day]++;
        patientPharmacyCount[patientId][pharmacyAddress][day]++;
        usedPrescriptions[prescriptionHash] = true;

        emit PrescriptionSubmitted(doctorNFTId, patientId, pharmacyAddress, prescriptionHash, block.timestamp);

        return true;
    }

    // ============ VIEW FUNCTIONS ============

    /**
     * @dev Gets daily prescription count for a doctor
     * @param doctor Doctor's address
     * @param day Day key (timestamp / 86400)
     * @return Number of prescriptions issued that day
     */
    function getDoctorDailyCount(address doctor, uint256 day) external view returns (uint256) {
        return doctorDailyCount[doctor][day];
    }

    /**
     * @dev Gets today's prescription count for a doctor
     * @param doctor Doctor's address
     * @return Number of prescriptions issued today
     */
    function getDoctorTodayCount(address doctor) external view returns (uint256) {
        return doctorDailyCount[doctor][_getCurrentDayKey()];
    }

    /**
     * @dev Gets pharmacy visit count for a patient
     * @param patientId Patient identifier
     * @param pharmacy Pharmacy address
     * @param day Day key
     * @return Number of visits to this pharmacy that day
     */
    function getPatientPharmacyCount(string memory patientId, address pharmacy, uint256 day)
        external
        view
        returns (uint256)
    {
        return patientPharmacyCount[patientId][pharmacy][day];
    }

    /**
     * @dev Gets today's pharmacy visit count for a patient
     * @param patientId Patient identifier
     * @param pharmacy Pharmacy address
     * @return Number of visits to this pharmacy today
     */
    function getPatientPharmacyTodayCount(string memory patientId, address pharmacy) external view returns (uint256) {
        return patientPharmacyCount[patientId][pharmacy][_getCurrentDayKey()];
    }

    /**
     * @dev Checks if a prescription hash has been used
     * @param prescriptionHash The hash to check
     * @return True if already used
     */
    function isPrescriptionUsed(bytes32 prescriptionHash) external view returns (bool) {
        return usedPrescriptions[prescriptionHash];
    }

    // ============ ADMIN FUNCTIONS ============

    /**
     * @dev Updates the Doctor NFT contract address
     * @param newDoctorNFT Address of new NFT contract
     */
    function setDoctorNFT(address newDoctorNFT) external onlyOwner {
        require(newDoctorNFT != address(0), "Invalid NFT address");
        address oldContract = address(doctorNFT);
        doctorNFT = IHealDoctorNFT(newDoctorNFT);
        emit DoctorNFTContractUpdated(oldContract, newDoctorNFT, msg.sender);
    }

    // ============ INTERNAL FUNCTIONS ============

    /**
     * @dev Gets current day key (days since epoch)
     * @return Current day identifier
     */
    function _getCurrentDayKey() internal view returns (uint256) {
        return block.timestamp / SECONDS_PER_DAY;
    }

    /**
     * @dev Gets day key for a specific timestamp
     * @param timestamp Unix timestamp
     * @return Day identifier
     */
    function _getDayKey(uint256 timestamp) internal pure returns (uint256) {
        return timestamp / SECONDS_PER_DAY;
    }


}
