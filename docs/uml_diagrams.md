# TouchSpeak AI — UML Diagrams

All diagrams are in Mermaid syntax — render them on GitHub, in VS Code (Mermaid
preview extension), or at https://mermaid.live

## 1. Use Case Diagram

```mermaid
flowchart LR
    User((Non-Verbal User))
    Caregiver((Caregiver))

    subgraph TouchSpeak AI System
        UC1[Select Icon / Phrase]
        UC2[Hear Text-to-Speech]
        UC3[Select Emotion]
        UC4[View Frequent Phrases]
        UC5[Get AI Phrase Suggestions]
        UC6[Trigger Emergency SOS]
        UC7[Switch Language]
        UC8[Manage Profile]
        UC9[Receive Emergency Alert]
        UC10[View User Location]
    end

    User --> UC1
    User --> UC2
    User --> UC3
    User --> UC4
    User --> UC5
    User --> UC6
    User --> UC7
    User --> UC8
    Caregiver --> UC9
    Caregiver --> UC10
    UC6 -.triggers.-> UC9
```

## 2. Class Diagram

```mermaid
classDiagram
    class User {
        +ObjectId id
        +String name
        +int age
        +String preferred_language
        +Caregiver caregiver
        +List~EmergencyContact~ emergency_contacts
        +createProfile()
        +updatePreferences()
    }

    class Caregiver {
        +String name
        +String phone
        +String email
        +String fcm_token
    }

    class CommunicationEvent {
        +ObjectId id
        +ObjectId user_id
        +String icon_id
        +String language
        +String phrase_text
        +DateTime timestamp
    }

    class FrequentPhrase {
        +ObjectId id
        +ObjectId user_id
        +String icon_id
        +int use_count
        +bool is_favorite
        +DateTime last_used
    }

    class EmergencyLog {
        +ObjectId id
        +ObjectId user_id
        +String message
        +GeoPoint location
        +bool caregiver_notified
        +DateTime timestamp
    }

    class PhrasePredictor {
        -List history
        +frequency_scores() dict
        +recency_scores() dict
        +sequence_scores() dict
        +predict_top_n(n) list
    }

    class NotificationService {
        +send_caregiver_alert(caregiver, message, lat, lng) bool
    }

    User "1" --> "1" Caregiver
    User "1" --> "*" CommunicationEvent
    User "1" --> "*" FrequentPhrase
    User "1" --> "*" EmergencyLog
    PhrasePredictor ..> CommunicationEvent : reads history
    EmergencyLog ..> NotificationService : triggers
```

## 3. Sequence Diagram — Icon Tap to Speech Output

```mermaid
sequenceDiagram
    actor U as Non-Verbal User
    participant App as Flutter App
    participant TTS as On-device TTS
    participant API as Flask API
    participant DB as MongoDB Atlas
    participant ML as Phrase Predictor

    U->>App: Taps "Water" icon
    App->>TTS: speak("I need water")
    TTS-->>U: Audio output (instant)
    App->>API: POST /communication/select
    API->>DB: Insert communication_history
    API->>DB: Upsert frequently_used_phrases
    API-->>App: 200 OK {phrase_text}
    App->>API: GET /predict/{user_id}
    API->>DB: Fetch history
    API->>ML: predict_top_n(history)
    ML-->>API: [water, food, help]
    API-->>App: predictions
    App-->>U: Updated suggestion strip
```

## 4. Sequence Diagram — Emergency SOS

```mermaid
sequenceDiagram
    actor U as User
    participant App as Flutter App
    participant Geo as Geolocator
    participant API as Flask API
    participant DB as MongoDB Atlas
    participant FCM as Firebase Cloud Messaging
    actor C as Caregiver

    U->>App: Taps SOS button
    App->>Geo: getCurrentPosition()
    Geo-->>App: {lat, lng}
    App->>API: POST /emergency/sos
    API->>DB: Insert emergency_logs
    API->>DB: Fetch user.caregiver
    API->>FCM: send push notification
    FCM-->>C: "Emergency alert + location"
    API-->>App: {caregiver_notified: true}
    App-->>U: "Caregiver notified"
```

## 5. Activity Diagram — Communication Flow

```mermaid
flowchart TD
    Start([Start]) --> Open[Open TouchSpeak App]
    Open --> Board[View Communication Board]
    Board --> Choose{User Action?}
    Choose -->|Tap Need Icon| Speak1[Convert to Speech]
    Choose -->|Tap Emotion Icon| Speak2[Convert to Speech]
    Choose -->|Tap SOS| SOS[Emergency Flow]
    Speak1 --> Log[Log to Communication History]
    Speak2 --> Log
    Log --> Predict[AI Updates Predictions]
    Predict --> Board
    SOS --> Location[Get GPS Location]
    Location --> Notify[Notify Caregiver via FCM]
    Notify --> LogEmergency[Store Emergency Log]
    LogEmergency --> End([End])
```
