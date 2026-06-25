# Requirements Document

## Introduction

Adaza POS is a point-of-sale system for the "Adaza" business, built with Flutter and targeting web first, with planned expansion to mobile and Windows desktop. The system uses a cloud backend (Firebase/Firestore) so data stays in sync across platforms. The initial release serves a single, non-technical owner who needs to manage products and inventory, record sales, track income and expenses, and view a clear dashboard of business health. Product entry supports scanning through a phone or web camera now, with the scanning input source abstracted so a hardware barcode scanner or IoT device can be added later. Authentication is kept simple for the single owner but is designed so staff accounts with roles can be introduced without rework. The interface follows the ADAZA brand palette (teal, copper/bronze, and gold on a cream background) and emphasizes a minimalist, aesthetic, and easy-to-understand experience.

## Glossary

- **POS_System**: The Adaza point-of-sale application, including its Flutter front end and Firebase/Firestore cloud backend.
- **Owner**: The single business owner who is the primary authenticated user of the initial release.
- **Staff_User**: A future non-owner user account assigned a role with scoped permissions.
- **Auth_Service**: The component responsible for authenticating users and enforcing access control.
- **Product**: A sellable item tracked in the system with attributes such as name, barcode, price, cost, and stock quantity.
- **Inventory**: The collection of Product stock quantities and their changes over time.
- **Scan_Source**: The abstracted input interface that supplies a scanned barcode value, regardless of whether the value comes from a device camera or external hardware.
- **Camera_Scanner**: A Scan_Source implementation that reads barcodes using a phone or web camera.
- **Sale**: A recorded transaction in which one or more Products are sold, capturing quantities, prices, and total amount.
- **Income_Record**: A recorded entry representing money received, including Sale revenue and other income.
- **Expense_Record**: A recorded entry representing money spent.
- **Dashboard**: The summary view presenting visual and list-based information about sales, profit, and inventory status.
- **Low_Stock_Threshold**: The Product-level stock quantity at or below which the Product is flagged as low stock.
- **Sync_Service**: The component that persists data to and retrieves data from the Firestore cloud backend across platforms.

## Requirements

### Requirement 1: Owner Authentication

**User Story:** As the Owner, I want to sign in securely with a simple account, so that only I can access my business data while staff accounts can be added later.

#### Acceptance Criteria

1. WHEN the Owner submits valid sign-in credentials, THE Auth_Service SHALL grant access to the POS_System.
2. IF the Owner submits invalid sign-in credentials, THEN THE Auth_Service SHALL deny access and display an authentication error message.
3. WHILE no user is authenticated, THE POS_System SHALL restrict access to product, inventory, sales, income, expense, and dashboard features.
4. WHEN the Owner chooses to sign out, THE Auth_Service SHALL end the session and return to the sign-in screen.
5. THE Auth_Service SHALL associate each authenticated session with a role attribute to support future Staff_User roles.

### Requirement 2: Product Management

**User Story:** As the Owner, I want to add, edit, and remove products with their details, so that my catalog stays accurate.

#### Acceptance Criteria

1. WHEN the Owner submits a new Product with a name, price, cost, and barcode, THE POS_System SHALL create the Product and persist it through the Sync_Service.
2. IF the Owner submits a Product without a required field, THEN THE POS_System SHALL reject the submission and display which required field is missing.
3. WHEN the Owner edits an existing Product, THE POS_System SHALL save the updated Product attributes through the Sync_Service.
4. WHEN the Owner deletes a Product, THE POS_System SHALL remove the Product from the catalog through the Sync_Service.
5. IF the Owner submits a Product with a barcode that already exists, THEN THE POS_System SHALL reject the submission and display a duplicate-barcode error message.
6. THE POS_System SHALL display the catalog of Products as a searchable list.

### Requirement 3: Barcode Scanning

**User Story:** As the Owner, I want to scan a product barcode using my camera, so that I can identify products quickly without typing.

#### Acceptance Criteria

1. WHEN the Owner initiates a scan, THE POS_System SHALL request a barcode value from the active Scan_Source.
2. WHEN the Camera_Scanner reads a barcode value, THE POS_System SHALL return the decoded barcode value to the requesting feature.
3. IF a scanned barcode matches an existing Product, THEN THE POS_System SHALL display the matching Product.
4. IF a scanned barcode matches no existing Product, THEN THE POS_System SHALL offer to create a new Product pre-filled with the scanned barcode value.
5. THE POS_System SHALL access barcode input through the Scan_Source interface so that additional Scan_Source implementations can be added without changing scanning callers.
6. IF camera access is denied or unavailable, THEN THE POS_System SHALL display a scanning-unavailable message and allow manual barcode entry.

### Requirement 4: Inventory Monitoring

**User Story:** As the Owner, I want to track stock levels and get low-stock alerts, so that I can restock before running out.

#### Acceptance Criteria

1. WHEN a Sale is recorded, THE POS_System SHALL decrease the stock quantity of each sold Product by the sold quantity through the Sync_Service.
2. WHEN the Owner adjusts a Product stock quantity, THE POS_System SHALL persist the adjusted quantity through the Sync_Service.
3. WHILE a Product stock quantity is at or below its Low_Stock_Threshold, THE POS_System SHALL flag the Product as low stock.
4. THE POS_System SHALL display the list of Products flagged as low stock on the Dashboard.
5. IF a Sale would reduce a Product stock quantity below zero, THEN THE POS_System SHALL reject the Sale and display an insufficient-stock message.

### Requirement 5: Sales Recording

**User Story:** As the Owner, I want to record sales transactions, so that revenue and inventory stay accurate.

#### Acceptance Criteria

1. WHEN the Owner adds one or more Products to a Sale and confirms it, THE POS_System SHALL create the Sale with line quantities, unit prices, and a total amount.
2. WHEN a Sale is confirmed, THE POS_System SHALL persist the Sale through the Sync_Service and create a corresponding Income_Record.
3. THE POS_System SHALL calculate the Sale total amount as the sum of each line quantity multiplied by its unit price.
4. IF the Owner attempts to confirm a Sale with no Product lines, THEN THE POS_System SHALL reject the Sale and display an empty-sale message.
5. THE POS_System SHALL display recorded Sales as a list ordered by transaction date.

### Requirement 6: Income and Expense Tracking

**User Story:** As the Owner, I want to record income and expenses, so that I can understand my profit.

#### Acceptance Criteria

1. WHEN the Owner submits an Expense_Record with an amount, category, and date, THE POS_System SHALL create the Expense_Record and persist it through the Sync_Service.
2. WHEN the Owner submits an Income_Record that is not derived from a Sale, THE POS_System SHALL create the Income_Record and persist it through the Sync_Service.
3. IF the Owner submits an Income_Record or Expense_Record with a non-positive amount, THEN THE POS_System SHALL reject the submission and display an invalid-amount message.
4. THE POS_System SHALL display Income_Records and Expense_Records as lists filterable by date range.
5. THE POS_System SHALL calculate profit for a selected date range as total Income_Records minus total Expense_Records within that range.

### Requirement 7: Dashboard

**User Story:** As the Owner, I want a dashboard with visual summaries, so that I can understand my business at a glance.

#### Acceptance Criteria

1. THE Dashboard SHALL display total sales for the current day and the current week as visual summaries.
2. THE Dashboard SHALL display profit for the current day and the current week.
3. THE Dashboard SHALL display the list of Products flagged as low stock.
4. WHEN underlying sales, income, expense, or inventory data changes, THE Dashboard SHALL reflect the updated values on next load.
5. WHERE no data exists for a selected period, THE Dashboard SHALL display a zero-value or empty-state summary instead of an error.

### Requirement 8: Cross-Platform Data Synchronization

**User Story:** As the Owner, I want my data stored in the cloud, so that it is consistent and available across the platforms I use.

#### Acceptance Criteria

1. WHEN the Owner creates, updates, or deletes data, THE Sync_Service SHALL persist the change to the Firestore cloud backend.
2. WHEN the POS_System loads on a supported platform, THE Sync_Service SHALL retrieve the Owner's current data from the Firestore cloud backend.
3. IF a data operation fails due to loss of network connectivity, THEN THE Sync_Service SHALL display a synchronization-error message and retain the unsynced change for retry.
4. THE POS_System SHALL run on the web platform in the initial release.
5. THE POS_System SHALL use platform-independent application logic so that mobile and Windows desktop platforms can be supported without rewriting core features.

### Requirement 9: User Interface and Branding

**User Story:** As a non-technical Owner, I want a clear, attractive interface, so that I can operate the system without confusion.

#### Acceptance Criteria

1. THE POS_System SHALL apply the ADAZA color palette of teal, copper/bronze, and gold on a cream background across all screens.
2. THE POS_System SHALL present primary actions for product management, scanning, sales, and dashboard within a navigable layout reachable from the main screen.
3. WHEN a user action succeeds or fails, THE POS_System SHALL display a clear confirmation or error message describing the outcome.
4. THE POS_System SHALL present each screen with a minimalist layout that limits primary actions to those relevant to the current task.
