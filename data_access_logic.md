1. Create a New Customer Record

// Service: create#Customer 

FUNCTION createCustomer(InputData data) {
  
    // 1. Validate Input
    
    IF (data.firstName IS EMPTY OR data.lastName IS EMPTY) {
        RETURN ERROR "First Name and Last Name are required."
    }

    BEGIN TRANSACTION
    
    TRY {
        // 2. Generate a unique ID
        String partyId = ec.entity.makeValue("Party").setSequencedIdPrimary().get("party_id")
        
        // 3. Create the Base Party Record
        ec.entity.makeValue("Party")
            .set("party_id", partyId)
            .set("party_type_id", "PERSON")
            .set("status_id", "PARTY_ENABLED")
            .create()

        // 4. Create the Specific Person Record
        ec.entity.makeValue("Person")
            .set("party_id", partyId)
            .set("first_name", data.firstName)
            .set("last_name", data.lastName)
            .set("date_of_birth", data.dateOfBirth)
            .create()

        // -------------------------------------------------------------------------
        // 5. CREATE CONTACT MECHANISMS (Expanded UDM Logic)
        // -------------------------------------------------------------------------
        
        // A. CREATE EMAIL 
        IF (data.email IS NOT NULL) {
            String emailCmId = ec.entity.makeValue("ContactMech").setSequencedIdPrimary().get("contact_mech_id")
            
            // i. Base ContactMech (Store email in info_string)
            ec.entity.makeValue("ContactMech")
                .set("contact_mech_id", emailCmId)
                .set("contact_mech_type_id", "EMAIL_ADDRESS")
                .set("info_string", data.email)
                .create()
                
            // ii. Link Email to Party
            ec.entity.makeValue("PartyContactMech")
                .set("party_id", partyId)
                .set("contact_mech_id", emailCmId)
                .set("from_date", CURRENT_TIMESTAMP)
                .create()
                
            // iii. Set Purpose for Email
            ec.entity.makeValue("PartyContactMechPurpose")
                .set("party_id", partyId)
                .set("contact_mech_id", emailCmId)
                .set("contact_mech_purpose_type_id", "PRIMARY_EMAIL")
                .set("from_date", CURRENT_TIMESTAMP)
                .create()
        }
        
        // B. CREATE SHIPPING ADDRESS
        IF (data.shippingAddress IS NOT NULL) {
            String addrCmId = ec.entity.makeValue("ContactMech").setSequencedIdPrimary().get("contact_mech_id")
            
            // i. Base ContactMech
            ec.entity.makeValue("ContactMech")
                .set("contact_mech_id", addrCmId)
                .set("contact_mech_type_id", "POSTAL_ADDRESS")
                .create()
                
            // ii. Extended PostalAddress Table
            ec.entity.makeValue("PostalAddress")
                .set("contact_mech_id", addrCmId)
                .set("to_name", data.shippingAddress.toName)
                .set("address1", data.shippingAddress.address1)
                .set("city", data.shippingAddress.city)
                .set("postal_code", data.shippingAddress.postalCode)
                .set("country_geo_id", data.shippingAddress.country)
                .create()
                
            // iii. Link Address to Party
            ec.entity.makeValue("PartyContactMech")
                .set("party_id", partyId)
                .set("contact_mech_id", addrCmId)
                .set("from_date", CURRENT_TIMESTAMP)
                .create()
                
            // iv. Set Purpose for Address (Shipping & Billing)
            ec.entity.makeValue("PartyContactMechPurpose")
                .set("party_id", partyId)
                .set("contact_mech_id", addrCmId)
                .set("contact_mech_purpose_type_id", "SHIPPING_LOCATION")
                .set("from_date", CURRENT_TIMESTAMP)
                .create()
                
            // If this is also the Billing address, you just add another purpose record
            ec.entity.makeValue("PartyContactMechPurpose")
                .set("party_id", partyId)
                .set("contact_mech_id", addrCmId)
                .set("contact_mech_purpose_type_id", "BILLING_LOCATION")
                .set("from_date", CURRENT_TIMESTAMP)
                .create()
        }

        // C. CREATE TELECOM NUMBER (Phone)
        IF (data.phoneNumber IS NOT NULL) {
            String phoneCmId = ec.entity.makeValue("ContactMech").setSequencedIdPrimary().get("contact_mech_id")
            
            // i. Base ContactMech
            ec.entity.makeValue("ContactMech")
                .set("contact_mech_id", phoneCmId)
                .set("contact_mech_type_id", "TELECOM_NUMBER")
                .create()
                
            // ii. Extended TelecomNumber Table
            ec.entity.makeValue("TelecomNumber")
                .set("contact_mech_id", phoneCmId)
                .set("country_code", data.phoneNumber.countryCode)
                .set("area_code", data.phoneNumber.areaCode)
                .set("contact_number", data.phoneNumber.number)
                .create()
                
            // iii. Link Phone to Party
            ec.entity.makeValue("PartyContactMech")
                .set("party_id", partyId)
                .set("contact_mech_id", phoneCmId)
                .set("from_date", CURRENT_TIMESTAMP)
                .create()
                
            // iv. Set Purpose for Phone
            ec.entity.makeValue("PartyContactMechPurpose")
                .set("party_id", partyId)
                .set("contact_mech_id", phoneCmId)
                .set("contact_mech_purpose_type_id", "PRIMARY_PHONE")
                .set("from_date", CURRENT_TIMESTAMP)
                .create()
        }
        
        // -------------------------------------------------------------------------
        // 6. Set Preferences
        // -------------------------------------------------------------------------
        IF (data.marketingOptIn IS NOT NULL) {
            ec.entity.makeValue("Preferences")
                .set("party_id", partyId)
                .set("preference_type", "MARKETING_OPT_IN")
                .set("preference_value", data.marketingOptIn)
                .create()
        }

        COMMIT TRANSACTION
        RETURN SUCCESS WITH partyId
        
    } CATCH (Exception e) {
        ROLLBACK TRANSACTION
        RETURN ERROR "Failed to create customer: " + e.getMessage()
    }
}

2. Retrieve a Customer Record

// Service: get#CustomerDetails 

FUNCTION getCustomer(String partyId) {
    
    // 1. Fetch Basic Person details (Acts as our primary check)
    
    Record personRecord = ec.entity.find("Person").condition("party_id", partyId).one()
    
    IF (personRecord IS NULL) {
        RETURN ERROR "Customer not found."
    }
    
    // Create the response object
    CustomerDTO response = new CustomerDTO()
    response.basicInfo = personRecord
    response.emails = []
    response.addresses = []
    response.phones = []
    
    // 2. Fetch Active Relationships
    // Get all Contact Mechanisms currently tied to this party
    List activePartyContactMechs = ec.entity.find("PartyContactMech")
        .condition("party_id", partyId)
        .conditionDate("from_date", "thru_date", CURRENT_TIMESTAMP)
        .list()
        
    // 3. Iterate and Resolve Details for each Mechanism
    FOR EACH pcm IN activePartyContactMechs {
        
        String cmId = pcm.contact_mech_id
        
        // A. Fetch the Base Contact Mech (to get the Type and InfoString)
        Record baseCm = ec.entity.find("ContactMech").condition("contact_mech_id", cmId).one()
        
        // B. Fetch the Active Purposes (e.g. Shipping, Billing, Primary)
        List purposes = ec.entity.find("PartyContactMechPurpose")
            .condition("party_id", partyId)
            .condition("contact_mech_id", cmId)
            .conditionDate("from_date", "thru_date", CURRENT_TIMESTAMP)
            .list()
        
        // Extract just the purpose strings into a list (e.g. ["SHIPPING_LOCATION", "BILLING_LOCATION"])
        List purposeList = purposes.map(p -> p.contact_mech_purpose_type_id)
        
        // C. Route the logic based on the Type of Contact Mechanism
        SWITCH (baseCm.contact_mech_type_id) {
            
            CASE "EMAIL_ADDRESS":
                response.emails.add({
                    contactMechId: cmId,
                    emailAddress: baseCm.info_string,
                    purposes: purposeList
                })
                BREAK
                
            CASE "POSTAL_ADDRESS":
                // Fetch the extended table data
                Record address = ec.entity.find("PostalAddress").condition("contact_mech_id", cmId).one()
                IF (address IS NOT NULL) {
                    response.addresses.add({
                        contactMechId: cmId,
                        toName: address.to_name,
                        address1: address.address1,
                        city: address.city,
                        postalCode: address.postal_code,
                        country: address.country_geo_id,
                        purposes: purposeList
                    })
                }
                BREAK
                
            CASE "TELECOM_NUMBER":
                // Fetch the extended table data
                Record phone = ec.entity.find("TelecomNumber").condition("contact_mech_id", cmId).one()
                IF (phone IS NOT NULL) {
                    response.phones.add({
                        contactMechId: cmId,
                        countryCode: phone.country_code,
                        areaCode: phone.area_code,
                        number: phone.contact_number,
                        purposes: purposeList
                    })
                }
                BREAK
        }
    }
        
    // 4. Fetch Preferences
    List preferences = ec.entity.find("Preferences")
        .condition("party_id", partyId)
        .list()
        
    response.preferences = preferences.map(pref -> {
        key: pref.preference_type,
        value: pref.preference_value
    })

    // 5. Return Aggregated Payload
    RETURN SUCCESS WITH response
}

3. Update an Existing Customer Record

// Service: update#Customer 

FUNCTION updateCustomer(String partyId, InputData updateData) {
    
    BEGIN TRANSACTION
    
    TRY {
        // -------------------------------------------------------------------------
        // 1. UPDATE BASIC INFORMATION (Safe to update in-place)
        // -------------------------------------------------------------------------
        Record person = ec.entity.find("Person").condition("party_id", partyId).one()
        
        IF (person IS NULL) {
            RETURN ERROR "Customer not found."
        }
        
        IF (updateData.firstName OR updateData.lastName OR updateData.dateOfBirth) {
            person.setFields(updateData, true, "first_name", "last_name", "date_of_birth")
            person.update()
        }
        
        // -------------------------------------------------------------------------
        // 2. UPDATE EMAIL (Expire Old -> Create New)
        // -------------------------------------------------------------------------
        IF (updateData.newEmail IS NOT NULL) {
            
            // A. Find the currently active PRIMARY_EMAIL
            Record activeEmailPurpose = ec.entity.find("PartyContactMechPurpose")
                .condition("party_id", partyId)
                .condition("contact_mech_purpose_type_id", "PRIMARY_EMAIL")
                .conditionDate("from_date", "thru_date", CURRENT_TIMESTAMP).one()
            
            // B. Soft-Expire the old Email
            IF (activeEmailPurpose != NULL) {
                String oldCmId = activeEmailPurpose.contact_mech_id
                
                // Expire the Purpose
                activeEmailPurpose.set("thru_date", CURRENT_TIMESTAMP).update()
                
                // Expire the Relationship wrapper
                Record activeEmailMech = ec.entity.find("PartyContactMech")
                    .condition("party_id", partyId).condition("contact_mech_id", oldCmId)
                    .conditionDate("from_date", "thru_date", CURRENT_TIMESTAMP).one()
                IF (activeEmailMech != NULL) activeEmailMech.set("thru_date", CURRENT_TIMESTAMP).update()
            }
            
            // C. Create the New Email
            String newEmailCmId = ec.entity.makeValue("ContactMech").setSequencedIdPrimary().get("contact_mech_id")
            
            ec.entity.makeValue("ContactMech")
                .set("contact_mech_id", newEmailCmId)
                .set("contact_mech_type_id", "EMAIL_ADDRESS")
                .set("info_string", updateData.newEmail).create()
                
            ec.entity.makeValue("PartyContactMech")
                .set("party_id", partyId).set("contact_mech_id", newEmailCmId)
                .set("from_date", CURRENT_TIMESTAMP).create()
                
            ec.entity.makeValue("PartyContactMechPurpose")
                .set("party_id", partyId).set("contact_mech_id", newEmailCmId)
                .set("contact_mech_purpose_type_id", "PRIMARY_EMAIL")
                .set("from_date", CURRENT_TIMESTAMP).create()
        }

        // -------------------------------------------------------------------------
        // 3. UPDATE POSTAL ADDRESS (Expire Old -> Create New)
        // -------------------------------------------------------------------------
        IF (updateData.newShippingAddress IS NOT NULL) {
            
            // A. Find the currently active SHIPPING_LOCATION
            Record activeShippingPurpose = ec.entity.find("PartyContactMechPurpose")
                .condition("party_id", partyId)
                .condition("contact_mech_purpose_type_id", "SHIPPING_LOCATION")
                .conditionDate("from_date", "thru_date", CURRENT_TIMESTAMP).one()
                
            // B. Soft-Expire the old Address
            IF (activeShippingPurpose != NULL) {
                String oldAddrId = activeShippingPurpose.contact_mech_id
                activeShippingPurpose.set("thru_date", CURRENT_TIMESTAMP).update()
                
                Record oldPartyMech = ec.entity.find("PartyContactMech")
                    .condition([party_id: partyId, contact_mech_id: oldAddrId])
                    .conditionDate("from_date", "thru_date", CURRENT_TIMESTAMP).one()
                IF (oldPartyMech != NULL) oldPartyMech.set("thru_date", CURRENT_TIMESTAMP).update()
            }
            
            // C. Create the New Address
            String newAddrId = ec.entity.makeValue("ContactMech").setSequencedIdPrimary().get("contact_mech_id")
            
            ec.entity.makeValue("ContactMech")
                .set("contact_mech_id", newAddrId).set("contact_mech_type_id", "POSTAL_ADDRESS").create()
                
            ec.entity.makeValue("PostalAddress")
                .set("contact_mech_id", newAddrId)
                .set("to_name", updateData.newShippingAddress.toName)
                .set("address1", updateData.newShippingAddress.address1)
                .set("city", updateData.newShippingAddress.city)
                .set("postal_code", updateData.newShippingAddress.postalCode)
                .set("country_geo_id", updateData.newShippingAddress.country).create()
                
            ec.entity.makeValue("PartyContactMech")
                .set("party_id", partyId).set("contact_mech_id", newAddrId)
                .set("from_date", CURRENT_TIMESTAMP).create()
                
            ec.entity.makeValue("PartyContactMechPurpose")
                .set("party_id", partyId).set("contact_mech_id", newAddrId)
                .set("contact_mech_purpose_type_id", "SHIPPING_LOCATION")
                .set("from_date", CURRENT_TIMESTAMP).create()
        }

        // -------------------------------------------------------------------------
        // 4. UPDATE TELECOM NUMBER (Expire Old -> Create New)
        // -------------------------------------------------------------------------
        IF (updateData.newPhoneNumber IS NOT NULL) {
            
            // A. Find currently active PRIMARY_PHONE
            Record activePhonePurpose = ec.entity.find("PartyContactMechPurpose")
                .condition("party_id", partyId)
                .condition("contact_mech_purpose_type_id", "PRIMARY_PHONE")
                .conditionDate("from_date", "thru_date", CURRENT_TIMESTAMP).one()
                
            // B. Soft-Expire the old Phone
            IF (activePhonePurpose != NULL) {
                String oldPhoneId = activePhonePurpose.contact_mech_id
                activePhonePurpose.set("thru_date", CURRENT_TIMESTAMP).update()
                
                Record oldPartyPhone = ec.entity.find("PartyContactMech")
                    .condition([party_id: partyId, contact_mech_id: oldPhoneId])
                    .conditionDate("from_date", "thru_date", CURRENT_TIMESTAMP).one()
                IF (oldPartyPhone != NULL) oldPartyPhone.set("thru_date", CURRENT_TIMESTAMP).update()
            }
            
            // C. Create the New Phone
            String newPhoneId = ec.entity.makeValue("ContactMech").setSequencedIdPrimary().get("contact_mech_id")
            
            ec.entity.makeValue("ContactMech")
                .set("contact_mech_id", newPhoneId).set("contact_mech_type_id", "TELECOM_NUMBER").create()
                
            ec.entity.makeValue("TelecomNumber")
                .set("contact_mech_id", newPhoneId)
                .set("country_code", updateData.newPhoneNumber.countryCode)
                .set("area_code", updateData.newPhoneNumber.areaCode)
                .set("contact_number", updateData.newPhoneNumber.number).create()
                
            ec.entity.makeValue("PartyContactMech")
                .set("party_id", partyId).set("contact_mech_id", newPhoneId)
                .set("from_date", CURRENT_TIMESTAMP).create()
                
            ec.entity.makeValue("PartyContactMechPurpose")
                .set("party_id", partyId).set("contact_mech_id", newPhoneId)
                .set("contact_mech_purpose_type_id", "PRIMARY_PHONE")
                .set("from_date", CURRENT_TIMESTAMP).create()
        }

        // -------------------------------------------------------------------------
        // 5. UPDATE PREFERENCES (Safe to update in-place)
        // -------------------------------------------------------------------------
        IF (updateData.preferences IS NOT NULL) {
            FOR EACH pref IN updateData.preferences {
                
                // Attempt to find existing preference
                Record prefRecord = ec.entity.find("Preferences")
                    .condition([party_id: partyId, preference_type: pref.key]).one()
                    
                IF (prefRecord IS NOT NULL) {
                    // Update in place if it exists
                    prefRecord.set("preference_value", pref.value).update()
                } ELSE {
                    // Create if it didn't previously exist
                    ec.entity.makeValue("Preferences")
                        .set("party_id", partyId)
                        .set("preference_type", pref.key)
                        .set("preference_value", pref.value).create()
                }
            }
        }

        COMMIT TRANSACTION
        RETURN SUCCESS WITH "Customer details updated successfully."
        
    } CATCH (Exception e) {
        ROLLBACK TRANSACTION
        RETURN ERROR "Failed to update customer: " + e.getMessage()
    }
}

4. Delete a Customer Record

// Service: disable#Customer 

FUNCTION deleteCustomer(String partyId) {
    
    BEGIN TRANSACTION
    
    TRY {
            // 2. SOFT DELETE logic: Disable the Party 
        Record party = ec.entity.find("Party").condition("party_id", partyId).one()
        party.set("status_id", "PARTY_DISABLED")
        party.update()
        
        // 3. Expire all active contact mechanisms immediately
        List activeMechs = ec.entity.find("PartyContactMech")
            .condition("party_id", partyId)
            .conditionDate("from_date", "thru_date", CURRENT_TIMESTAMP)
            .list()
            
        FOR EACH mech IN activeMechs {
            mech.set("thru_date", CURRENT_TIMESTAMP)
            mech.update()
        }
        
               COMMIT TRANSACTION
        RETURN SUCCESS WITH "Customer disabled successfully."
        
    } CATCH(Exception e) {
        ROLLBACK TRANSACTION
        RETURN ERROR "Deletion failed: " + e.getMessage()
    }
}












