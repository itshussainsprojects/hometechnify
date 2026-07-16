# RULES.md
# On-Demand Home Services App – AI Development Rules

## 1. ABSOLUTE AUTHORITY
This file overrides ALL assumptions.
If any instruction conflicts with this file, THIS FILE WINS.

## 2. STACK LOCK (DO NOT CHANGE)
- Frontend: Flutter (Dart)
- Backend: Node.js + Express
- Database: MongoDB
- Maps: OpenStreetMap + MapLibre
- Realtime: Socket.IO
- Calls: WebRTC
- Auth: Email OTP (FREE ONLY)
- Storage: Local server (/uploads)
- Payments: Cash on Service (MVP)
- Admin Panel: React OR HTML + Bootstrap

NO Firebase  
NO Twilio  
NO Google Maps  
NO Paid APIs  

## 3. DEVELOPMENT FLOW (MANDATORY)
The project MUST follow strict phases:

Phase 1 → Setup  
Phase 2 → User App UI  
Phase 3 → Provider App UI  
Phase 4 → Chat UI  
Phase 5 → Backend Setup  
Phase 6 → Auth APIs  
Phase 7 → Core APIs  
Phase 8 → Verification  
Phase 9 → Admin Panel  
Phase 10 → Integration & Cleanup  

🚫 Skipping phases is NOT allowed.

## 4. STOP & ASK RULE
After EACH phase:
- Summarize work
- List files created/changed
- ASK for approval
- WAIT for confirmation

NO AUTO-CONTINUE.

## 5. NO FEATURE CREEP
AI must NOT:
- Add extra features
- Improve scope without permission
- Add paid services
- Add “nice-to-have” features

## 6. UI RULES
- Mobile-first
- Clean layouts
- No hardcoded logic in UI
- Dummy data until backend phase

## 7. BACKEND RULES
- REST APIs only
- Clean MVC structure
- Proper error handling
- JWT-based auth
- Role-based access

## 8. DATABASE RULES
- MongoDB collections must be normalized
- Use indexes
- Use timestamps
- No unstructured dumping

## 9. SECURITY RULES
- Validate all inputs
- Protect routes
- Never expose secrets
- No sensitive logs

## 10. PLAY STORE SAFE
- No prohibited permissions
- Clear user consent
- Secure data handling

## 11. AI BEHAVIOR RULE
If confused:
STOP → ASK → WAIT

Violating these rules = FAILURE.
