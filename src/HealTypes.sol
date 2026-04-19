// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title HealTypes
 * @dev Shared types and structures used across Heal protocol contracts
 * @notice This library contains all shared structs and enums to maintain consistency
 */
library HealTypes {
    
    /**
     * @dev Doctor credential structure stored with NFT
     * @param licenseNumber Official medical license identifier
     * @param fullName Doctor's complete legal name
     * @param specialty Medical specialization (e.g., "Cardiology")
     * @param registeredAt Timestamp when NFT was minted
     * @param isActive Whether the doctor can issue prescriptions
     */
    struct Doctor {
        string licenseNumber;
        string fullName;
        string specialty;
        uint256 registeredAt;
        bool isActive;
    }

    /**
     * @dev Complete prescription data structure
     * @param prescriptionHash Keccak256 hash of prescription content
     * @param expiry Unix timestamp when prescription expires
     * @param doctor Address of the prescribing doctor
     * @param patientId Unique patient identifier (off-chain)
     * @param medicine Name of prescribed medication
     * @param dosage Dosage instructions (e.g., "500mg twice daily")
     * @param issuedAt Timestamp when prescription was created
     */
    struct Prescription {
        bytes32 prescriptionHash;
        uint256 expiry;
        address doctor;
        string patientId;
        string medicine;
        string dosage;
        uint256 issuedAt;
    }

    /**
     * @dev Result of prescription verification
     * @param verified True if prescription passed all checks
     * @param reason Human-readable success/failure message
     * @param doctor Address of prescribing doctor
     * @param medicine Name of prescribed medication
     * @param expiry Expiration timestamp of prescription
     */
    struct VerificationResult {
        bool verified;
        string reason;
        address doctor;
        string medicine;
        uint256 expiry;
    }

    /**
     * @dev Input data for creating a new prescription (off-chain use)
     * @param patientId Unique patient identifier
     * @param medicine Name of medication
     * @param dosage Dosage instructions
     * @param validDays Number of days prescription is valid
     */
    struct PrescriptionInput {
        string patientId;
        string medicine;
        string dosage;
        uint256 validDays;
    }

    /**
     * @dev Doctor registration input data
     * @param licenseNumber Official medical license
     * @param fullName Complete legal name
     * @param specialty Area of specialization
     */
    struct DoctorRegistration {
        string licenseNumber;
        string fullName;
        string specialty;
    }

    /**
     * @dev Daily counter tracking structure
     * @param dayKey Day identifier (block.timestamp / 86400)
     * @param count Number of prescriptions/pharmacy visits
     */
    struct DailyCounter {
        uint256 dayKey;
        uint256 count;
    }

    /**
     * @dev Doctor status enumeration
     * @notice Used to track doctor's current state
     */
    enum DoctorStatus {
        Unregistered,  // No NFT minted
        Active,        // Can issue prescriptions
        Revoked,       // License revoked by regulator
        Suspended      // Temporarily suspended (future use)
    }

    /**
     * @dev Verification failure reasons enumeration
     * @notice Standardized failure codes for frontend handling
     */
    enum VerificationFailure {
        None,                               // Success
        DoctorNotRegistered,                // No NFT found for doctor
        DoctorRevoked,                      // Doctor's license is revoked
        PrescriptionExpired,                // Past expiry date
        InvalidSignature,                   // Signature doesn't match doctor
        DoctorDailyLimitExceeded,           // >30 prescriptions today
        PatientPharmacyLimitExceeded,       // >3 pharmacies today
        InvalidNFT,                         // Token doesn't exist
        UnauthorizedAccess                  // Caller not authorized
    }

    /**
     * @dev QR Code data structure (for frontend reference)
     * @notice This is what gets encoded in QR codes
     */
    struct QRCodeData {
        uint256 doctorNFTId;
        bytes32 prescriptionHash;
        bytes signature;
        string patientId;
        string medicine;
        string dosage;
        uint256 expiry;
        uint256 timestamp;
    }

    /**
     * @dev Event data for off-chain indexing
     * @notice Used by subgraph/indexer services
     */
    struct IndexedPrescriptionEvent {
        uint256 doctorNFTId;
        string patientId;
        address pharmacy;
        uint256 timestamp;
        bool verified;
        string failureReason;
    }
}

/**
 * @title IHealDoctorNFT
 * @dev Interface for HealDoctorNFT contract
 * @notice Dev 2 will use this interface to interact with Dev 1's contract
 */
interface IHealDoctorNFT {
    /**
     * @dev Returns the owner of a given token ID
     * @param tokenId The NFT token ID
     * @return Address of the token owner
     */
    function ownerOf(uint256 tokenId) external view returns (address);
    
    /**
     * @dev Checks if a doctor's license is active
     * @param tokenId The NFT token ID to check
     * @return True if doctor can issue prescriptions
     */
    function isDoctorActive(uint256 tokenId) external view returns (bool);
    
    /**
     * @dev Gets complete doctor information
     * @param tokenId The NFT token ID
     * @return Doctor struct with all metadata
     */
    function getDoctorInfo(uint256 tokenId) external view returns (HealTypes.Doctor memory);
    
    /**
     * @dev Gets token ID for a doctor's address
     * @param doctor Address of the doctor
     * @return Token ID if registered, reverts if not found
     */
    function getDoctorByAddress(address doctor) external view returns (uint256);
    
    /**
     * @dev Returns the regulator address
     * @return Address authorized to revoke NFTs
     */
    function regulator() external view returns (address);
}

/**
 * @title IHealPrescriptionVerifier
 * @dev Interface for HealPrescriptionVerifier contract
 * @notice Frontend will use this interface for verification
 */
interface IHealPrescriptionVerifier {
    /**
     * @dev Verifies a prescription without state changes (view-only)
     * @param doctorNFTId Doctor's NFT token ID
     * @param prescriptionHash Hash of prescription data
     * @param signature Doctor's signature of the hash
     * @param patientId Patient identifier
     * @param pharmacyAddress Pharmacy performing verification
     * @param expiry Prescription expiration timestamp
     * @return verified True if prescription is valid
     * @return reason Human-readable success/failure message
     */
    function verifyPrescription(
        uint256 doctorNFTId,
        bytes32 prescriptionHash,
        bytes memory signature,
        string memory patientId,
        address pharmacyAddress,
        uint256 expiry
    ) external view returns (bool verified, string memory reason);
    
    /**
     * @dev Submits verified prescription and updates counters
     * @notice This modifies state and requires gas
     * @param doctorNFTId Doctor's NFT token ID
     * @param prescriptionHash Hash of prescription data
     * @param signature Doctor's signature
     * @param patientId Patient identifier
     * @param pharmacyAddress Pharmacy address
     * @param expiry Prescription expiration
     * @return success True if submission succeeded
     */
    function submitVerifiedPrescription(
        uint256 doctorNFTId,
        bytes32 prescriptionHash,
        bytes memory signature,
        string memory patientId,
        address pharmacyAddress,
        uint256 expiry
    ) external returns (bool);
    
    /**
     * @dev Gets daily prescription count for a doctor
     * @param doctor Doctor's address
     * @param day Day key (timestamp / 86400)
     * @return Number of prescriptions issued that day
     */
    function getDoctorDailyCount(address doctor, uint256 day) external view returns (uint256);
    
    /**
     * @dev Gets pharmacy visit count for a patient
     * @param patientId Patient identifier
     * @param pharmacy Pharmacy address
     * @param day Day key
     * @return Number of visits to this pharmacy today
     */
    function getPatientPharmacyCount(
        string memory patientId,
        address pharmacy,
        uint256 day
    ) external view returns (uint256);
}

/**
 * @title Constants
 * @dev Shared constants across Heal protocol
 */
library Constants {
    /// @dev Maximum prescriptions per doctor per day
    uint256 public constant MAX_PRESCRIPTIONS_PER_DAY = 30;
    
    /// @dev Maximum pharmacies a patient can visit per day
    uint256 public constant MAX_PHARMACIES_PER_PATIENT = 3;
    
    /// @dev Seconds in a day (for timestamp calculations)
    uint256 public constant SECONDS_PER_DAY = 86400;
    
    /// @dev Default prescription validity period (30 days)
    uint256 public constant DEFAULT_PRESCRIPTION_VALIDITY = 30 days;
    
    /// @dev Maximum prescription validity (90 days)
    uint256 public constant MAX_PRESCRIPTION_VALIDITY = 90 days;
    
    /// @dev Domain separator version for EIP-712 (future use)
    string public constant DOMAIN_VERSION = "1";
}

/**
 * @title Errors
 * @dev Standardized error messages for consistent user feedback
 */
library Errors {
    // Doctor NFT Errors
    string public constant DOCTOR_ALREADY_REGISTERED = "Doctor already registered";
    string public constant LICENSE_REQUIRED = "License number required";
    string public constant NAME_REQUIRED = "Full name required";
    string public constant NOT_REGULATOR = "Caller is not the regulator";
    string public constant TOKEN_DOES_NOT_EXIST = "Token does not exist";
    string public constant ALREADY_REVOKED = "Doctor already revoked";
    string public constant SOULBOUND_TRANSFER = "Soulbound: Cannot transfer";
    string public constant INVALID_ADDRESS = "Invalid address provided";
    
    // Verification Errors
    string public constant DOCTOR_NOT_REGISTERED = "Doctor not registered";
    string public constant DOCTOR_REVOKED = "Doctor license revoked";
    string public constant PRESCRIPTION_EXPIRED = "Prescription expired";
    string public constant INVALID_SIGNATURE = "Invalid signature - fake prescription";
    string public constant DOCTOR_LIMIT_EXCEEDED = "Doctor exceeded 30 prescriptions today";
    string public constant PATIENT_LIMIT_EXCEEDED = "Patient visited too many pharmacies today (max 3)";
    string public constant INVALID_PRESCRIPTION = "Invalid prescription data";
    
    // General Errors
    string public constant ZERO_ADDRESS = "Zero address not allowed";
    string public constant UNAUTHORIZED = "Unauthorized access";
    string public constant INVALID_PARAMETER = "Invalid parameter";
}

/**
 * @title Events
 * @dev Standardized event definitions for indexing
 */
library Events {
    /**
     * @dev Emitted when a new doctor NFT is minted
     */
    event DoctorMinted(
        uint256 indexed tokenId,
        address indexed doctor,
        string licenseNumber,
        string fullName,
        string specialty,
        uint256 registeredAt
    );
    
    /**
     * @dev Emitted when a doctor's NFT is revoked
     */
    event DoctorRevoked(
        uint256 indexed tokenId,
        address indexed doctor,
        address revokedBy,
        uint256 revokedAt
    );
    
    /**
     * @dev Emitted when a doctor is paused/unpaused
     */
    event DoctorStatusChanged(
        uint256 indexed tokenId,
        address indexed doctor,
        HealTypes.DoctorStatus oldStatus,
        HealTypes.DoctorStatus newStatus,
        address changedBy
    );
    
    /**
     * @dev Emitted when a prescription is verified
     */
    event PrescriptionVerified(
        uint256 indexed doctorNFTId,
        string patientId,
        address indexed pharmacy,
        bool verified,
        string reason,
        uint256 timestamp
    );
    
    /**
     * @dev Emitted when a verified prescription is submitted
     */
    event PrescriptionSubmitted(
        uint256 indexed doctorNFTId,
        string patientId,
        address indexed pharmacy,
        bytes32 prescriptionHash,
        uint256 timestamp
    );
    
    /**
     * @dev Emitted when daily counters reset (admin event)
     */
    event DailyCountersReset(
        uint256 dayKey,
        uint256 resetAt
    );
    
    /**
     * @dev Emitted when regulator address is updated
     */
    event RegulatorUpdated(
        address indexed oldRegulator,
        address indexed newRegulator,
        address updatedBy
    );
}

/**
 * @title Utils
 * @dev Shared utility functions
 */
library Utils {
    /**
     * @dev Converts a timestamp to day key
     * @param timestamp Unix timestamp
     * @return dayKey Day identifier (days since epoch)
     */
    function getDayKey(uint256 timestamp) internal pure returns (uint256) {
        return timestamp / Constants.SECONDS_PER_DAY;
    }
    
    /**
     * @dev Gets current day key
     * @return Current day identifier
     */
    function getCurrentDayKey() internal view returns (uint256) {
        return block.timestamp / Constants.SECONDS_PER_DAY;
    }
    
    /**
     * @dev Validates an address is not zero
     * @param addr Address to validate
     * @return True if address is valid
     */
    function isValidAddress(address addr) internal pure returns (bool) {
        return addr != address(0);
    }
    
    /**
     * @dev Validates string is not empty
     * @param str String to validate
     * @return True if string has content
     */
    function isNotEmptyString(string memory str) internal pure returns (bool) {
        return bytes(str).length > 0;
    }
    
    /**
     * @dev Compares two strings for equality
     * @param a First string
     * @param b Second string
     * @return True if strings are equal
     */
    function stringEquals(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
    }
    
    /**
     * @dev Converts VerificationFailure enum to string message
     * @param failure VerificationFailure enum value
     * @return Human-readable error message
     */
    function failureToString(HealTypes.VerificationFailure failure) internal pure returns (string memory) {
        if (failure == HealTypes.VerificationFailure.None) return "";
        if (failure == HealTypes.VerificationFailure.DoctorNotRegistered) return Errors.DOCTOR_NOT_REGISTERED;
        if (failure == HealTypes.VerificationFailure.DoctorRevoked) return Errors.DOCTOR_REVOKED;
        if (failure == HealTypes.VerificationFailure.PrescriptionExpired) return Errors.PRESCRIPTION_EXPIRED;
        if (failure == HealTypes.VerificationFailure.InvalidSignature) return Errors.INVALID_SIGNATURE;
        if (failure == HealTypes.VerificationFailure.DoctorDailyLimitExceeded) return Errors.DOCTOR_LIMIT_EXCEEDED;
        if (failure == HealTypes.VerificationFailure.PatientPharmacyLimitExceeded) return Errors.PATIENT_LIMIT_EXCEEDED;
        if (failure == HealTypes.VerificationFailure.InvalidNFT) return Errors.TOKEN_DOES_NOT_EXIST;
        if (failure == HealTypes.VerificationFailure.UnauthorizedAccess) return Errors.UNAUTHORIZED;
        return "Unknown error";
    }
}