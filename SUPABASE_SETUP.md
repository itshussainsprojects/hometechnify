# Supabase Setup Guide for HomeTechnify

## ✅ What's Implemented

1. **Supabase Service** - `lib/core/services/supabase_service.dart`
   - Document storage (CNIC, Selfie)
   - Provider verification system
   - Realtime updates
   - Admin approval/rejection

2. **Provider Registration** - Enhanced with:
   - Supabase document upload
   - Verification request submission
   - Google Sign-In integration
   - Proper error handling

3. **Admin Verification Panel** - `lib/features/admin/screens/provider_verification_admin_screen.dart`
   - View pending verifications
   - Approve/Reject providers
   - View documents
   - Real-time updates

## 🚀 Setup Instructions

### 1. Create Supabase Account
1. Go to [https://supabase.com](https://supabase.com)
2. Sign up for free account
3. Create new project

### 2. Get Project Credentials
In your Supabase project dashboard:
1. Go to **Project Settings** → **API**
2. Copy:
   - Project URL
   - anon/public key
   - service_role key

### 3. Configure Flutter App
Create `.env` file in project root:
```env
SUPABASE_URL=your_project_url
SUPABASE_ANON_KEY=your_anon_key
```

### 4. Initialize Supabase in Flutter
Add to `main.dart`:
```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );
  
  runApp(const MyApp());
}
```

### 5. Setup Database Tables
Run these SQL queries in Supabase SQL Editor:

```sql
-- Provider Verifications Table
CREATE TABLE provider_verifications (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  provider_id TEXT NOT NULL,
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  phone TEXT,
  service TEXT NOT NULL,
  experience TEXT NOT NULL,
  cnic_front_url TEXT,
  cnic_back_url TEXT,
  selfie_with_cnic_url TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  submitted_at TIMESTAMPTZ DEFAULT NOW(),
  reviewed_at TIMESTAMPTZ,
  reviewed_by TEXT,
  rejection_reason TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Enable Realtime
ALTER TABLE provider_verifications REPLICA IDENTITY FULL;
```

### 6. Setup Storage
1. Go to **Storage** in Supabase dashboard
2. Create bucket named `documents`
3. Set bucket to public or configure RLS policies:
```sql
-- Allow public read access to documents
CREATE POLICY "Public Read Access" 
ON storage.objects FOR SELECT 
TO public 
USING (bucket_id = 'documents');

-- Allow authenticated users to upload
CREATE POLICY "Authenticated Upload" 
ON storage.objects FOR INSERT 
TO authenticated 
WITH CHECK (bucket_id = 'documents');
```

### 7. Folder Structure
Documents will be stored in:
```
documents/
├── provider-docs/
│   ├── cnic/
│   │   ├── user123_cnic_front.jpg
│   │   └── user123_cnic_back.jpg
│   └── selfies/
│       └── user123_selfie_cnic.jpg
```

## 📱 Usage Flow

### Provider Registration:
1. User fills registration form
2. Uploads CNIC documents
3. Clicks "Complete Registration"
4. Documents uploaded to Supabase Storage
5. Verification request saved to database
6. Admin gets notification (realtime)

### Admin Verification:
1. Admin logs into admin panel
2. Goes to `/admin/providers/verification`
3. Views pending requests
4. Clicks documents to review
5. Approves or rejects with reason
6. Provider gets status update

### Realtime Updates:
- Provider verification status updates in real-time
- Admin dashboard auto-refreshes
- No need to manually refresh

## 🔧 Key Features

- ✅ **Free tier**: Supabase free tier sufficient for development
- ✅ **Document storage**: 1GB free storage
- ✅ **Realtime**: WebSocket-based realtime updates
- ✅ **Security**: Row Level Security (RLS) policies
- ✅ **Scalable**: Easily upgrade to paid plans
- ✅ **Backup**: Automatic backups included

## 🎯 Benefits

1. **No server setup**: Supabase handles database + storage
2. **Free**: Everything works on free tier
3. **Realtime**: Instant updates between admin and providers
4. **Secure**: Built-in authentication and security
5. **Reliable**: Enterprise-grade infrastructure
6. **Easy migration**: Simple to upgrade if needed

## 📞 Support
If you need help with setup, just ask! The system is ready to work with your Supabase project.