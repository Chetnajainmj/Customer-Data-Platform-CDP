Data Integration with Shopify Mapping

| Shopify Customer API    | Customer Data Platform (CDP)                             |
|-------------------------|----------------------------------------------------------|
| customer.id             | party.externalId                                         |
| customer.firstName      | person.firstName                                         |
| customer.lastName       | person.lastName                                          |
| customer.email          | contact_mech.infoString                                  |
| customer.verified_email | party_contact_mech.verified                              |
| customer.phone          | Telecom_number.countrycode telecome_number.contactNumber |
| customer.address1       | postal_address.address1                                  |
| customer.address2       | postal_address.address2                                  |
| customer.city           | postal_address.city                                      |
| customer.zip            | postal_address.postalcode                                |
| customer.provincecode   | postal_address.statepProvinceGeoId                       |
| customer.countrycode    | postal_address.countryGeoId                              |


Handling Data Type Differences
Customer ID: Shopify returns a unique customer ID (or GraphQL Global ID). Store it as party.externalId to maintain synchronization with Shopify.
Boolean: verified_email is stored directly as a Boolean (true/false).
Phone Number: Parse the phone number into countryCode and contactNumber

Handling Multi-Valued Fields (Addresses)
The Shopify addresses field is an array of address objects. Instead of storing the entire array in one field, create one PostalAddress record for each address and associate each with the same Party.


