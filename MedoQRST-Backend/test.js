const axios = require('axios');
axios.get("http://localhost:1232/insertVitals", {
  params: {
    Admission_no: "000021",
    Recorded_at: "2025-04-20T09:30:00", // ISO format for datetime
    Blood_pressure: "120/80",
    Respiration_rate: 18,
    Pulse_rate: 75,
    Oxygen_saturation: 98.5,
    Temperature: 98,
    Random_blood_sugar: 110.5,
    
    Associate_diagnosis: "Hypertension",
    Procedure: "ECG",
    Primary_diagnosis: "Cardiac Arrhythmia",
    Receiving_note: "Patient reported chest pain on arrival"
  }
})
.then(response => {
  console.log("✅ Success:", response.data);
})
.catch(error => {
  console.error("❌ Error:", error.response ? error.response.data : error.message);
});
