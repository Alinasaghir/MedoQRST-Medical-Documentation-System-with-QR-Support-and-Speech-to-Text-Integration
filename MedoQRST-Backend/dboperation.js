const express = require("express");
const sql = require("mssql/msnodesqlv8");
const config = require("./dbconfig");
const cors = require("cors");
const nodemailer = require('nodemailer');
const { google } = require('googleapis');
const { OAuth2Client } = require('google-auth-library');
const app = express();
const PORT = 1232;
app.use(express.json());
const moment = require('moment');
// Enable CORS for your Firebase Hosting domain
app.use(cors({}));
const bcrypt = require("bcrypt");

async function connectToDatabase() {
  try {
    let pool = await sql.connect(config);
    console.log("Connected to SQL Server!");
    pool.close(); // Close connection after use
  } catch (error) {
    console.error("Connection failed: ", error.message);
  }
}

connectToDatabase();
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: 'medoqrst@gmail.com',
    pass: 'kada ojcd itxv brwk',
  },
});
app.get("/updatePrimaryDiagnosis", async (req, res) => {
  const data = {
    Admission_no: req.query.Admission_no,
    Primary_diagnosis: req.query.Primary_diagnosis
  };

  try {
    let pool = await sql.connect(config);
   
    await pool.request()
      .input("Admission_no", sql.NVarChar, data.Admission_no)
      .input("Primary_diagnosis", sql.NVarChar(sql.MAX), data.Primary_diagnosis)
      .query(`
        UPDATE [medoQRST].[dbo].[PatientDetails]
        SET Primary_diagnosis =
          CASE
            WHEN CAST(Primary_diagnosis AS NVARCHAR(MAX)) IS NULL OR LTRIM(RTRIM(CAST(Primary_diagnosis AS NVARCHAR(MAX)))) = ''
            THEN @Primary_diagnosis
            ELSE CAST(Primary_diagnosis AS NVARCHAR(MAX)) + ', ' + @Primary_diagnosis
          END
        WHERE Admission_no = @Admission_no
      `);

    res.status(200).send({ message: "Primary diagnosis updated successfully." });
  } catch (error) {
    console.error("Error updating primary diagnosis:", error.message);
    res.status(500).send({ error: "Error updating primary diagnosis." });
  }
});

// API for updating associated diagnosis (append mode)
app.get("/updateAssociatedDiagnosis", async (req, res) => {
  const data = {
    Admission_no: req.query.Admission_no,
    Associate_diagnosis: req.query.Associate_diagnosis
  };

  try {
    let pool = await sql.connect(config);
   
    await pool.request()
      .input("Admission_no", sql.NVarChar, data.Admission_no)
      .input("Associate_diagnosis", sql.NVarChar(sql.MAX), data.Associate_diagnosis)
      .query(`
        UPDATE [medoQRST].[dbo].[PatientDetails]
        SET Associate_diagnosis =
          CASE
            WHEN CAST(Associate_diagnosis AS NVARCHAR(MAX)) IS NULL OR LTRIM(RTRIM(CAST(Associate_diagnosis AS NVARCHAR(MAX)))) = ''
            THEN @Associate_diagnosis
            ELSE CAST(Associate_diagnosis AS NVARCHAR(MAX)) + ', ' + @Associate_diagnosis
          END
        WHERE Admission_no = @Admission_no
      `);

    res.status(200).send({ message: "Associated diagnosis updated successfully." });
  } catch (error) {
    console.error("Error updating associated diagnosis:", error.message);
    res.status(500).send({ error: "Error updating associated diagnosis." });
  }
});

// API for updating procedure (append mode)
app.get("/updateProcedure", async (req, res) => {
  const data = {
    Admission_no: req.query.Admission_no,
    Procedure: req.query.Procedure
  };

  try {
    let pool = await sql.connect(config);
   
    await pool.request()
      .input("Admission_no", sql.NVarChar, data.Admission_no)
      .input("Procedure", sql.NVarChar(sql.MAX), data.Procedure)
      .query(`
        UPDATE [medoQRST].[dbo].[PatientDetails]
        SET [Procedure] =
          CASE
            WHEN CAST([Procedure] AS NVARCHAR(MAX)) IS NULL OR LTRIM(RTRIM(CAST([Procedure] AS NVARCHAR(MAX)))) = ''
            THEN @Procedure
            ELSE CAST([Procedure] AS NVARCHAR(MAX)) + ', ' + @Procedure
          END
        WHERE Admission_no = @Admission_no
      `);

    res.status(200).send({ message: "Procedure updated successfully." });
  } catch (error) {
    console.error("Error updating procedure:", error.message);
    res.status(500).send({ error: "Error updating procedure." });
  }
});

// API for updating receiving note (overwrite mode)
app.get("/updateReceivingNote", async (req, res) => {
  const data = {
    Admission_no: req.query.Admission_no,
    Receiving_note: req.query.Receiving_note
  };

  try {
    let pool = await sql.connect(config);
   
    await pool.request()
      .input("Admission_no", sql.NVarChar, data.Admission_no)
      .input("Receiving_note", sql.NVarChar(sql.MAX), data.Receiving_note)
      .query(`
        UPDATE [medoQRST].[dbo].[PatientDetails]
        SET Receiving_note = @Receiving_note
        WHERE Admission_no = @Admission_no
      `);

    res.status(200).send({ message: "Receiving note updated successfully." });
  } catch (error) {
    console.error("Error updating receiving note:", error.message);
    res.status(500).send({ error: "Error updating receiving note." });
  }
});

app.get('/discharge-details/:Admission_no', async (req, res) => {
  const { Admission_no } = req.params;

  try {
    await sql.connect(config);
    const request = new sql.Request();
    request.input('Admission_no', sql.NVarChar, Admission_no);


    const result = await request.query(`
SELECT
    d.Admission_no,
    d.Examination_findings,
    d.Discharge_treatment,
    d.Follow_up,
    d.Instructions,
    d.Condition_at_discharge,
    d.Doctor_id,
    d.Surgery,
    d.Operative_findings,
    r.CT_scan,
    r.MRI,
    r.Biopsy,
    r.Other_reports
FROM DischargeDetails d
LEFT JOIN DiagnosticReports r ON d.Admission_no = r.Admission_no
WHERE d.Admission_no = @Admission_no;

    `);

    if (result.recordset.length === 0) {
      return res.status(404).json({ message: 'No discharge details found' });
    }

    res.status(200).json(result.recordset);
  } catch (err) {
    console.error('Error:', err);
    res.status(500).json({ error: 'Internal Server Error' });
  } finally {
    sql.close();
  }
});

app.get('/user/:userId', async (req, res) => {
  const { userId } = req.params;

  // Ensure UserID starts with "N-"
  if (!userId.startsWith('N-')) {
    return res.status(400).json({ success: false, message: "Invalid UserID format" });
  }

  try {
    // Connect to SQL Server
    const pool = await sql.connect(config);

    // Query to fetch the User_name
    const result = await pool.request()
      .input('userId', sql.VarChar, userId)
      .query('SELECT User_name FROM [medoQRST].[dbo].[Login] WHERE UserID = @userId');

    if (result.recordset.length === 0) {
      return res.status(404).json({ success: false, message: "User not found" });
    }

    res.json({ success: true, userName: result.recordset[0].User_name });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  } finally {
    sql.close(); // Close the connection
  }
});

// Temporary storage for OTPs (in production, use a database or Redis)
const otpStorage = {};
app.post('/get-current-email', async (req, res) => {
  const { userId } = req.body;

  if (!userId) {
    return res.status(400).json({ success: false, message: 'User ID is required' });
  }

  try {
    await sql.connect(config);
    let currentEmail = null;

    // First check Doctor table
    const doctorResult = await sql.query`
      SELECT Email FROM [medoQRST].[dbo].[Doctor] WHERE DoctorID = ${userId}
    `;

    if (doctorResult.recordset.length > 0) {
      currentEmail = doctorResult.recordset[0].Email.trim();
    } else {
      // If not found in Doctor table, check Nurse table
      const nurseResult = await sql.query`
        SELECT Email FROM [medoQRST].[dbo].[Nurse] WHERE NurseID = ${userId}
      `;

      if (nurseResult.recordset.length > 0) {
        currentEmail = nurseResult.recordset[0].Email.trim();
      }
    }

    if (!currentEmail) {
      return res.status(404).json({ success: false, message: 'User not found in Doctor or Nurse tables' });
    }

    res.status(200).json({ success: true, email: currentEmail });
  } catch (err) {
    console.error('Error fetching current email:', err);
    res.status(500).json({ success: false, message: 'Internal server error' });
  } finally {
    await sql.close();
  }
});


app.post('/send-email-change-notification', async (req, res) => {
  const { currentEmail, newEmail } = req.body;

  try {
    const mailOptions = {
      from: 'medoqrst@gmail.com',
      to: currentEmail,
      subject: '🔔 Important: Your Email Address Has Been Updated',
      html: `
        <html>
          <head>
            <style>
              body {
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                margin: 0;
                padding: 0;
                background-color: #f4f4f4;
                color: #333;
              }
              .email-container {
                max-width: 600px;
                margin: 20px auto;
                background: #ffffff;
                border-radius: 12px;
                overflow: hidden;
                box-shadow: 0 5px 15px rgba(0, 0, 0, 0.15);
              }
              .header {
                background: linear-gradient(135deg, #007BFF, #0056b3);
                color: #ffffff;
                padding: 25px;
                text-align: center;
              }
              .header h1 {
                margin: 0;
                font-size: 24px;
                font-weight: bold;
              }
              .content {
                padding: 30px;
                text-align: center;
              }
              .content p {
                font-size: 16px;
                margin-bottom: 15px;
                color: #444;
              }
              .email-highlight {
                font-size: 20px;
                font-weight: bold;
                color: #D32F2F;
                background: #f0f0f0;
                padding: 12px 20px;
                border-radius: 8px;
                display: inline-block;
                margin: 20px 0;
              }
              .alert {
                font-size: 16px;
                color: #ff5722;
                font-weight: bold;
                margin-top: 20px;
              }
              .support-box {
                margin-top: 25px;
                padding: 20px;
                background: #f8f9fa;
                border-radius: 8px;
                text-align: center;
                box-shadow: 0 2px 5px rgba(0, 0, 0, 0.1);
              }
              .support-box p {
                margin: 5px 0;
                font-size: 14px;
                color: #555;
              }
              .support-box a {
                color: #007BFF;
                text-decoration: none;
                font-weight: bold;
              }
              .footer {
                background: #f1f1f1;
                padding: 15px;
                text-align: center;
                font-size: 12px;
                color: #777;
              }
              .footer a {
                color: #007BFF;
                text-decoration: none;
              }
              .button {
                display: inline-block;
                padding: 12px 25px;
                font-size: 16px;
                font-weight: bold;
                color: #ffffff;
                background: #007BFF;
                border-radius: 6px;
                text-decoration: none;
                margin-top: 20px;
              }
            </style>
          </head>
          <body>
            <div class="email-container">
              <div class="header">
                <h1>🔔 Email Address Changed</h1>
              </div>
              <div class="content">
                <p>Hello,</p>
                <p>Your email address has been successfully updated.</p>
                <p class="email-highlight">${newEmail}</p>
                <p>If you made this change, no further action is needed.</p>
                <p class="alert">⚠️ If you did NOT make this change, please contact our support team immediately.</p>
                <a href="mailto:support@medoqr.com" class="button">Contact Support</a>
              </div>
              <div class="support-box">
                <p><strong>📧 Email Support:</strong> <a href="mailto:support@medoqr.com">support@medoqr.com</a></p>
                <p><strong>📞 Phone Support:</strong> +92 123 4567890</p>
              </div>
              <div class="footer">
                <p>Thank you,<br><strong>From MEDOQRST Team</strong></p>
              </div>
            </div>
          </body>
        </html>
      `,
    };
   

    await transporter.sendMail(mailOptions);
    res.status(200).json({ success: true, message: 'Notification email sent successfully' });
  } catch (err) {
    console.error('Error sending notification email:', err);
    res.status(500).json({ success: false, message: 'Failed to send notification email' });
  }
});


app.post("/send-otp", async (req, res) => {
  const { userId } = req.body;

  if (!userId) {
    return res.status(400).json({ success: false, message: "User ID is required" });
  }

  try {
    await sql.connect(config);
    let userEmail = null;

    // First check Doctor table
    const doctorResult = await sql.query`
      SELECT Email FROM [medoQRST].[dbo].[Doctor] WHERE DoctorID = ${userId}
    `;

    if (doctorResult.recordset.length > 0) {
      userEmail = doctorResult.recordset[0].Email.trim();
    } else {
      // If not found in Doctor table, check Nurse table
      const nurseResult = await sql.query`
        SELECT Email FROM [medoQRST].[dbo].[Nurse] WHERE NurseID = ${userId}
      `;

      if (nurseResult.recordset.length > 0) {
        userEmail = nurseResult.recordset[0].Email.trim();
      }
    }

    if (!userEmail) {
      return res.status(404).json({ success: false, message: "User not found in Doctor or Nurse tables" });
    }

    const otp = Math.floor(100000 + Math.random() * 900000).toString(); // 6-digit OTP
    otpStorage[userId] = otp;

    // Send OTP via email
    const mailOptions = {
      from: "medoqrst@gmail.com",
      to: userEmail,
      subject: "🔐 Your One-Time Password (OTP)",
      html: ` <html> <head> <style> body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 0; background-color: #f7f7f7; color: #333; } .email-container { max-width: 600px; margin: 20px auto; background: #ffffff; border-radius: 10px; overflow: hidden; box-shadow: 0 4px 10px rgba(0, 0, 0, 0.1); } .header { background: linear-gradient(135deg, #4CAF50, #45a049); color: #ffffff; padding: 20px; text-align: center; } .header h1 { margin: 0; font-size: 24px; font-weight: bold; } .content { padding: 30px; text-align: center; } .content h2 { font-size: 22px; color: #4CAF50; margin-bottom: 20px; } .otp-code { font-size: 28px; font-weight: bold; color: #D32F2F; background: #f0f0f0; padding: 15px; border-radius: 8px; margin: 20px 0; display: inline-block; } .footer { background: #f1f1f1; padding: 15px; text-align: center; font-size: 12px; color: #777; } .footer a { color: #4CAF50; text-decoration: none; } </style> </head> <body> <div class="email-container"> <div class="header"> <h1>🔐 OTP Verification</h1> </div> <div class="content"> <h2>Hello,</h2> <p>You requested a One-Time Password (OTP) to reset your password.</p> <div class="otp-code">${otp}</div> <p>This OTP is valid for <strong>5 minutes</strong>. Please do not share it with anyone.</p> <p>If you did not request this, please ignore this email.</p> </div> <div class="footer"> <p>Thank you,<br><strong>From MEDOQRST Team</strong></p> </div> </div> </body> </html> `,
    };

    await transporter.sendMail(mailOptions);

    res.status(200).json({ success: true, message: "OTP sent successfully" });
  } catch (err) {
    console.error("Error sending OTP:", err);
    res.status(500).json({ success: false, message: "Failed to send OTP" });
  } finally {
    // Close the SQL connection
    await sql.close();
  }
});
// Verify OTP
app.post("/verify-otp", async (req, res) => {
  const { userId, otp } = req.body;

  if (!otpStorage[userId] || otpStorage[userId] !== otp) {
    return res.status(400).json({ success: false, message: "Invalid OTP" });
  }

  // Clear OTP after verification
  delete otpStorage[userId];
  res.status(200).json({ success: true, message: "OTP verified successfully" });
});

// Update password
app.post("/update-password", async (req, res) => {
  const { userId, newPassword } = req.body;

  if (!userId || !newPassword) {
    return res.status(400).json({ success: false, message: "User ID and new password are required" });
  }

  try {
    // Hash the new password before saving it
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(newPassword, salt);

    await sql.connect(config);
    await sql.query`
      UPDATE [medoQRST].[dbo].[Login]
      SET Password = ${hashedPassword}  -- Store hashed password
      WHERE UserID = ${userId}
    `;

    res.status(200).json({ success: true, message: "Password updated successfully" });
  } catch (err) {
    console.error("Error updating password:", err);
    res.status(500).json({ success: false, message: "Failed to update password" });
  } finally {
    sql.close();
  }
});

// Validate Old Email
app.post('/validate-email', async (req, res) => {
  const { userId, oldEmail } = req.body;

  try {
    await sql.connect(config);
    const result = await sql.query`
      SELECT Email FROM Doctor WHERE DoctorID = ${userId}
    `;

    if (result.recordset.length > 0 && result.recordset[0].Email === oldEmail) {
      res.status(200).json({ success: true });
    } else {
      res.status(400).json({ success: false, message: 'Old email does not match' });
    }
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// Send Verification Email
// Send Verification Email
app.post('/send-verification-email', async (req, res) => {
  const { newEmail } = req.body;

  try {
    const otp = Math.floor(100000 + Math.random() * 900000).toString(); // Generate 6-digit OTP

    const mailOptions = {
      from: "medoqrst@gmail.com",
      to: newEmail,
      subject: "🔐 Your One-Time Password (OTP)",
      html: `
        <html>
          <head>
            <style>
              body {
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                margin: 0;
                padding: 0;
                background-color: #f7f7f7;
                color: #333;
              }
              .email-container {
                max-width: 600px;
                margin: 20px auto;
                background: #ffffff;
                border-radius: 10px;
                overflow: hidden;
                box-shadow: 0 4px 10px rgba(0, 0, 0, 0.1);
              }
              .header {
                background: linear-gradient(135deg, #4CAF50, #45a049);
                color: #ffffff;
                padding: 20px;
                text-align: center;
              }
              .header h1 {
                margin: 0;
                font-size: 24px;
                font-weight: bold;
              }
              .content {
                padding: 30px;
                text-align: center;
              }
              .content h2 {
                font-size: 22px;
                color: #4CAF50;
                margin-bottom: 20px;
              }
              .otp-code {
                font-size: 28px;
                font-weight: bold;
                color: #D32F2F;
                background: #f0f0f0;
                padding: 15px;
                border-radius: 8px;
                margin: 20px 0;
                display: inline-block;
              }
              .footer {
                background: #f1f1f1;
                padding: 15px;
                text-align: center;
                font-size: 12px;
                color: #777;
              }
              .footer a {
                color: #4CAF50;
                text-decoration: none;
              }
            </style>
          </head>
          <body>
            <div class="email-container">
              <div class="header">
                <h1>🔐 OTP Verification</h1>
              </div>
              <div class="content">
                <h2>Hello,</h2>
                <p>You requested a One-Time Password (OTP) for email verification.</p>
                <div class="otp-code">${otp}</div>
                <p>This OTP is valid for <strong>5 minutes</strong>. Please do not share it with anyone.</p>
                <p>If you did not request this, please ignore this email.</p>
              </div>
              <div class="footer">
                <p>Thank you,<br><strong>From MEDOQRST Team</strong></p>
              </div>
            </div>
          </body>
        </html>
      `,
    };
   

    await transporter.sendMail(mailOptions);

    res.status(200).json({ success: true, otp });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});
// Update Email
app.post('/update-email', async (req, res) => {
  const { userId, newEmail } = req.body;

  try {
    await sql.connect(config);
    await sql.query`
      UPDATE Doctor SET Email = ${newEmail} WHERE DoctorID = ${userId}
    `;

    res.status(200).json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});
app.get("/progress-note-today/:Admission_no", async (req, res) => {
  const { Admission_no } = req.params;
  const today = new Date().toISOString().split('T')[0]; // Get today's date in YYYY-MM-DD format

  try {
    let pool = await sql.connect(config);
    let query = `
      SELECT *
      FROM [medoQRST].[dbo].[Progress]
      WHERE Admission_no = @Admission_no
      AND CONVERT(date, Progress_Date) = @Today;
    `;

    let result = await pool.request()
      .input("Admission_no", sql.NVarChar, Admission_no)
      .input("Today", sql.Date, today)
      .query(query);

    if (result.recordset.length === 0) {
      return res.status(404).send({ message: "No progress note found for today" });
    }

    res.status(200).json(result.recordset[0]);
  } catch (error) {
    console.error("Error fetching today's progress note:", error.message);
    res.status(500).send({ error: "Error fetching today's progress note." });
  }
});
app.put("/update-progress-note/:Admission_no", async (req, res) => {
  const { Admission_no } = req.params;
  const { Notes, Reported_By } = req.body; // Include Reported_By in the request body
  const today = new Date().toISOString().split('T')[0]; // Get today's date in YYYY-MM-DD format

  if (!Admission_no || !Notes || !Reported_By) {
    return res.status(400).send({ error: "Admission_no, Notes, and Reported_By are required" });
  }

  try {
    let pool = await sql.connect(config);

    await pool.request()
      .input("Admission_no", sql.NVarChar, Admission_no)
      .input("Notes", sql.NVarChar, Notes)
      .input("Reported_By", sql.NVarChar, Reported_By) // Add Reported_By to the query
      .input("Today", sql.Date, today)
      .query(`
        UPDATE [medoQRST].[dbo].[Progress]
        SET Notes = @Notes, Reported_By = @Reported_By
        WHERE Admission_no = @Admission_no
        AND CONVERT(date, Progress_Date) = @Today;
      `);

    res.status(200).send({ message: "Progress note updated successfully." });
  } catch (error) {
    console.error("Error updating progress note:", error.message);
    res.status(500).send({ error: "Error updating progress note." });
  }
});app.put('/discharge-details/:Admission_no', async (req, res) => {
  const {
    Examination_findings,
    Discharge_treatment,
    Follow_up,
    Instructions,
    Condition_at_discharge,
    Doctor_id,
    Surgery,
    Operative_findings
  } = req.body;
  const { Admission_no } = req.params;

  if (!Admission_no || !Doctor_id) {
    return res.status(400).json({ error: 'Admission number and Doctor ID are required' });
  }

  try {
    await sql.connect(config);
    const request = new sql.Request();
   
    request.input('Admission_no', sql.NVarChar, Admission_no);
    request.input('Examination_findings', sql.NVarChar, Examination_findings || null);
    request.input('Discharge_treatment', sql.NVarChar, Discharge_treatment || null);
    request.input('Follow_up', sql.NVarChar, Follow_up || null);
    request.input('Instructions', sql.NVarChar, Instructions || null);
    request.input('Condition_at_discharge', sql.NVarChar, Condition_at_discharge || null);
    request.input('Doctor_id', sql.NVarChar, Doctor_id || null);
    request.input('Surgery', sql.NVarChar, Surgery || null);
    request.input('Operative_findings', sql.NVarChar, Operative_findings || null);

    const checkQuery = `SELECT * FROM DischargeDetails WHERE Admission_no = @Admission_no`;
    const checkResult = await request.query(checkQuery);

    if (checkResult.recordset.length > 0) {
      const updateQuery = `
        UPDATE DischargeDetails
        SET Examination_findings = @Examination_findings, Discharge_treatment = @Discharge_treatment,
            Follow_up = @Follow_up, Instructions = @Instructions, Condition_at_discharge = @Condition_at_discharge,
            Doctor_id = @Doctor_id, Surgery = @Surgery, Operative_findings = @Operative_findings
        WHERE Admission_no = @Admission_no
      `;
      await request.query(updateQuery);
      return res.status(200).json({ message: 'Discharge details updated successfully' });
    } else {
      const insertQuery = `
        INSERT INTO DischargeDetails (Admission_no, Examination_findings, Discharge_treatment, Follow_up,
            Instructions, Condition_at_discharge, Doctor_id, Surgery, Operative_findings)
        VALUES (@Admission_no, @Examination_findings, @Discharge_treatment, @Follow_up,
            @Instructions, @Condition_at_discharge, @Doctor_id, @Surgery, @Operative_findings)
      `;
      await request.query(insertQuery);
      return res.status(201).json({ message: 'Discharge details added successfully' });
    }
  } catch (err) {
    console.error('Error:', err);
    return res.status(500).json({ error: 'Internal server error' });
  } finally {
    sql.close();
  }
});


app.post('/diagnostic-reports', async (req, res) => {
  const { Admission_no, MRI, CT_scan, Biopsy, Other_reports, Disposal_status } = req.body;

  if (!Admission_no) {
    return res.status(400).json({ error: 'Admission number is required' });
  }
 
  try {
    // Connect to the database
    await sql.connect(config);
   
    // Create a new request
    const request = new sql.Request();
    request.input('Admission_no', sql.NVarChar, Admission_no || null);
    request.input('MRI', sql.NVarChar, MRI || null);
    request.input('CT_scan', sql.NVarChar, CT_scan || null);
    request.input('Biopsy', sql.NVarChar, Biopsy || null);
    request.input('Other_reports', sql.NVarChar, Other_reports || null);
    request.input('Disposal_status', sql.NVarChar, Disposal_status || null);


    // Check if the Admission_no exists in PatientDetails
    const admissionCheckQuery = `SELECT * FROM [medoQRST].[dbo].[PatientDetails] WHERE Admission_no = @Admission_no`;
    const admissionResult = await request.query(admissionCheckQuery);
   
    if (admissionResult.recordset.length === 0) {
      return res.status(404).json({ error: 'Admission number not found in PatientDetails' });
    }

    // Check if the record already exists in DiagnosticReports
    const checkQuery = `SELECT * FROM DiagnosticReports WHERE Admission_no = @Admission_no`;
    const checkResult = await request.query(checkQuery);

    if (checkResult.recordset.length > 0) {
      // Update existing record
      const updateQuery = `
        UPDATE DiagnosticReports
        SET
          MRI = @MRI,
          CT_scan = @CT_scan,
          Biopsy = @Biopsy,
          Other_reports = @Other_reports
        WHERE Admission_no = @Admission_no
      `;

      await request.query(updateQuery);
    } else {
      // Insert new record
      const insertQuery = `
        INSERT INTO DiagnosticReports (
          Admission_no, MRI, CT_scan, Biopsy, Other_reports
        ) VALUES (
          @Admission_no, @MRI, @CT_scan, @Biopsy, @Other_reports
        )
      `;

      await request.query(insertQuery);
    }

    // Update Disposal_status in PatientDetails table
    const patientUpdateQuery = `
      UPDATE [medoQRST].[dbo].[PatientDetails]
      SET Disposal_status = @Disposal_status
      WHERE Admission_no = @Admission_no
    `;
    await request.query(patientUpdateQuery);
   
    return res.status(200).json({ message: 'Record updated successfully, including Disposal Status' });
  } catch (err) {
    console.error('Error:', err);
    return res.status(500).json({ error: 'Internal server error' });
  } finally {
    // Close the database connection
    sql.close();
  }
});

app.post('/discharge-details', async (req, res) => {
  const {
    Admission_no,
    Examination_findings,
    Discharge_treatment,
    Follow_up,
    Instructions,
    Condition_at_discharge,
    Doctor_id,
    Surgery,
    Operative_findings
  } = req.body;

  if (!Admission_no || !Doctor_id) {
    return res.status(400).json({ error: 'Admission number and Doctor ID are required' });
  }

  try {
    await sql.connect(config);
    const request = new sql.Request();

    // Check if Admission_no exists in PatientDetails
    const checkQuery = `
      SELECT Admission_no
      FROM PatientDetails
      WHERE Admission_no = @Admission_no
    `;
    request.input('Admission_no', sql.NVarChar, Admission_no);

    const checkResult = await request.query(checkQuery);

    if (checkResult.recordset.length === 0) {
      return res.status(400).json({ error: 'Admission number does not exist in PatientDetails' });
    }

    // Insert into DischargeDetails
    request.input('Examination_findings', sql.NVarChar, Examination_findings || null);
    request.input('Discharge_treatment', sql.NVarChar, Discharge_treatment || null);
    request.input('Follow_up', sql.NVarChar, Follow_up || null);
    request.input('Instructions', sql.NVarChar, Instructions || null);
    request.input('Condition_at_discharge', sql.NVarChar, Condition_at_discharge || null);
    request.input('Doctor_id', sql.NVarChar, Doctor_id || null);
    request.input('Surgery', sql.NVarChar, Surgery || null);
    request.input('Operative_findings', sql.NVarChar, Operative_findings || null);

    const insertQuery = `
      INSERT INTO DischargeDetails (
        Admission_no, Examination_findings, Discharge_treatment, Follow_up,
        Instructions, Condition_at_discharge, Doctor_id,
        Surgery, Operative_findings
      ) VALUES (
        @Admission_no, @Examination_findings, @Discharge_treatment, @Follow_up,
        @Instructions, @Condition_at_discharge, @Doctor_id,
        @Surgery, @Operative_findings
      )
    `;

    await request.query(insertQuery);
    res.status(201).json({ message: 'Discharge details added successfully' });

  } catch (err) {
    console.error('Error:', err);
    res.status(500).json({ error: 'Internal Server Error' });
  } finally {
    sql.close();
  }
});

// Update or Insert Diagnostic Reports
app.put('/diagnostic-reports/:Admission_no', async (req, res) => {
  const { MRI, CT_scan, Biopsy, Other_reports } = req.body;
  const { Admission_no } = req.params;

  if (!Admission_no) {
    return res.status(400).json({ error: 'Admission number is required' });
  }

  try {
    await sql.connect(config);
    const request = new sql.Request();
    request.input('Admission_no', sql.NVarChar, Admission_no);
    request.input('MRI', sql.NVarChar, MRI || null);
    request.input('CT_scan', sql.NVarChar, CT_scan || null);
    request.input('Biopsy', sql.NVarChar, Biopsy || null);
    request.input('Other_reports', sql.NVarChar, Other_reports || null);

    // Check if record exists
    const checkQuery = `SELECT * FROM DiagnosticReports WHERE Admission_no = @Admission_no`;
    const checkResult = await request.query(checkQuery);

    if (checkResult.recordset.length > 0) {
      // Update existing record
      const updateQuery = `
        UPDATE DiagnosticReports
        SET MRI = @MRI, CT_scan = @CT_scan, Biopsy = @Biopsy, Other_reports = @Other_reports
        WHERE Admission_no = @Admission_no
      `;
      await request.query(updateQuery);
    } else {
      // Insert new record
      const insertQuery = `
        INSERT INTO DiagnosticReports (Admission_no, MRI, CT_scan, Biopsy, Other_reports)
        VALUES (@Admission_no, @MRI, @CT_scan, @Biopsy, @Other_reports)
      `;
      await request.query(insertQuery);
    }

    return res.status(200).json({ message: 'Diagnostic report updated successfully' });
  } catch (err) {
    console.error('Error:', err);
    return res.status(500).json({ error: 'Internal server error' });
  } finally {
    sql.close();
  }
});


app.get('/commentTypes', async (req, res) => {
  try {
    // Connect to the database
    await sql.connect(config);

    // Query the database for distinct comment types
    const result = await sql.query(`
      SELECT DISTINCT [Type_of_Comments]
      FROM [medoQRST].[dbo].[Consultation]
      WHERE [Type_of_Comments] IS NOT NULL
    `);

    // Extract the comment types from the result
    const commentTypes = result.recordset.map((row) => row.Type_of_Comments);

    // Send the result as JSON
    res.json(commentTypes);
  } catch (err) {
    console.error('Error fetching comment types:', err);
    res.status(500).send('Server error');
  } finally {
    // Close the database connection
    sql.close();
  }
});
app.get('/finddoctor', async (req, res) => {
  try {
    // Connect to SQL Server
    await sql.connect(config);
    const result = await sql.query(
      "SELECT UserID, Name, Role FROM [medoQRST].[dbo].[Users] WHERE Role IN ('Doctor', 'Nurse')"
    );

    // Convert data into JSON format
    const staffMap = {};
    result.recordset.forEach((row) => {
      staffMap[row.UserID] = {
        name: row.Name,
        role: row.Role,
      };
    });

    res.json(staffMap); // Return JSON { "DR001": { "name": "Dr. Ali", "role": "Doctor" }, ... }
  } catch (err) {
    console.error('Database query error:', err);
    res.status(500).json({ error: 'Internal Server Error' });
  } finally {
    sql.close();
  }
});
app.get("/ward-beds", async (req, res) => {
  const { ward_no } = req.query;

  if (!ward_no) {
    return res.status(400).send({ error: "Ward_no parameter is required" });
  }

  try {
    let pool = await sql.connect(config);
    let query = `
    SELECT DISTINCT
      pd.[Bed_no],
      pd.[Ward_no],
      CASE WHEN u.[UserID] IS NOT NULL THEN 1 ELSE 0 END AS hasPatient
    FROM
      [medoQRST].[dbo].[PatientDetails] pd
    LEFT JOIN
      [medoQRST].[dbo].[Users] u ON pd.[PatientID] = u.[UserID]
    WHERE
      pd.[Ward_no] = @WardNo
    ORDER BY
      pd.[Bed_no] ASC
    `;

    let result = await pool.request()
      .input("WardNo", sql.Int, ward_no)
      .query(query);

    console.log("Fetched beds for Ward No:", ward_no, result.recordset);

    if (result.recordset.length === 0) {
      return res.status(404).send({ message: "No beds found for the specified ward number" });
    }

    res.json(result.recordset);
  } catch (error) {
    console.error("Error: ", error.message);
    res.status(500).send({ error: "An error occurred while fetching ward beds" });
  }
});
app.get("/patient", async (req, res) => {
  const { ward_no, bed_no } = req.query;

  if (!ward_no || !bed_no) {
    return res.status(400).send({ error: "Ward_no and Bed_no parameters are required" });
  }

  try {
    let pool = await sql.connect(config);
    let query = `
    SELECT
    u.[Name] AS PatientName,
    pd.[Admission_no],
    u.[Age],
    u.[Gender],
    u.[Contact_number],
    u.[Alternate_contact_number],
    u.[Address] AS UserAddress,
    pd.[Admission_date],
    pd.[Admission_time],
    pd.[Mode_of_admission],
    doc.[Name] AS AdmittedunderthecareofDr,
    consPhysician.[Name] AS ConsultingDoctorName,  -- Fetch Consulting Doctor Name
    pd.[Receiving_note],
    pd.[Ward_no],
    pd.[Bed_no],
    pd.[Primary_diagnosis],
    pd.[Associate_diagnosis],
    pd.[Procedure],
    pd.[Summary],
    pd.[Disposal_status],
    dd.[Discharge_date],
    dd.[Discharge_time],
    nok.[Name] AS NextOfKinName,
    nok.[Address] AS NextOfKinAddress,
    nok.[Contact_no] AS NextOfKinContact,
    nok.[Relationship],
    pr.[Progress_Date],
    pr.[Notes],
    pr.[Reported_By],
    c.[Requesting_Physician],
    c.[Consulting_Physician],
    c.[Status],
    reqPhysician.[Name] AS RequestingPhysicianName,
    reqDept.[Specialization] AS RequestingPhysicianDepartment,
    consDept.[Specialization] AS ConsultingPhysicianDepartment,
    c.[Reason],
    c.[Date] AS ConsultationDate,
    c.[Time] AS ConsultationTime,
    c.[Additional_Description],
    c.[Type_of_Comments],

    mr.[Record_ID],
    mr.[Drug_ID],
    mr.[Date] AS MedicationDate,
    mr.[Time] AS MedicationTime,
    mr.[Monitored_By],
    mr.[Dosage],
    mr.[Shift],
    d.[Commercial_name] AS DrugCommercialName,
    d.[Generic_name] AS DrugGenericName,
    d.[Strength] AS DrugStrength,
    v.[Recorded_at],
    v.[Blood_pressure],
    v.[Respiration_rate],
    v.[Pulse_rate],
    v.[Oxygen_saturation],
    v.[Temperature],
    v.[Random_blood_sugar]
FROM
    [medoQRST].[dbo].[Users] u
LEFT JOIN
    [medoQRST].[dbo].[PatientDetails] pd ON u.[UserID] = pd.[PatientID]
LEFT JOIN
    [medoQRST].[dbo].[Users] doc ON pd.[Admitted_under_care_of] = doc.[UserID]
LEFT JOIN
    [medoQRST].[dbo].[Consultation] c ON pd.[Admission_no] = c.[Admission_no]
LEFT JOIN
    [medoQRST].[dbo].[Users] consPhysician ON c.[Consulting_Physician] = consPhysician.[UserID]  -- Join for Consulting Doctor Name
LEFT JOIN
    [medoQRST].[dbo].[NextOfKin] nok ON pd.[Admission_no] = nok.[Admission_no]
LEFT JOIN
    [medoQRST].[dbo].[Progress] pr ON pd.[Admission_no] = pr.[Admission_no]
LEFT JOIN
    [medoQRST].[dbo].[Users] reqPhysician ON c.[Requesting_Physician] = reqPhysician.[UserID]
LEFT JOIN
    [medoQRST].[dbo].[Doctor] reqDept ON c.[Requesting_Physician] = reqDept.[DoctorID]
LEFT JOIN
    [medoQRST].[dbo].[Doctor] consDept ON c.[Consulting_Physician] = consDept.[DoctorID]
LEFT JOIN
    [medoQRST].[dbo].[MedicationRecord] mr ON pd.[Admission_no] = mr.[Admission_no]
LEFT JOIN
    [medoQRST].[dbo].[Drug] d ON mr.[Drug_ID] = d.[DrugID]
LEFT JOIN
    [medoQRST].[dbo].[Vitals] v ON pd.[Admission_no] = v.[Admission_no]
LEFT JOIN
    [medoQRST].[dbo].[DischargeDetails] dd ON pd.[Admission_no] = dd.[Admission_no]
WHERE
       u.[Role] = 'Patient'
    AND pd.[Ward_no] = @WardNo
    AND pd.[Bed_no] = @BedNo
    AND pd.[Disposal_status] IS NULL;
    `;

    let result = await pool.request()
      .input("WardNo", sql.Int, ward_no)
      .input("BedNo", sql.Int, bed_no)
      .query(query);

    console.log("Fetched data for Ward No:", ward_no, "Bed No:", bed_no, result.recordset);

    if (result.recordset.length === 0) {
      return res.status(404).send({ message: "No data found for the specified ward and bed number" });
    }

    res.json(result.recordset);
  } catch (error) {
    console.error("Error: ", error.message);
    res.status(500).send({ error: "An error occurred while fetching data" });
  }
});
app.post('/resetPassword', async (req, res) => {
  const { userId, newPassword } = req.body;

  if (!userId || !newPassword) {
    return res.status(400).json({ error: 'User ID and new password are required' });
  }

  try {
    // Hash the new password before storing it
    const salt = await bcrypt.genSalt(10);
    const hashedPassword = await bcrypt.hash(newPassword, salt);

    await sql.connect(config);
    const result = await sql.query`
      UPDATE [dbo].[Login]
      SET Password = ${hashedPassword}  -- Store hashed password
      WHERE UserID = ${userId}
    `;

    if (result.rowsAffected[0] > 0) {
      res.json({ message: 'Password reset successfully' });
    } else {
      res.status(404).json({ error: 'User not found' });
    }
  } catch (error) {
    console.error('Error resetting password:', error);
    res.status(500).json({ error: 'Internal server error' });
  } finally {
    sql.close();
  }
});// API to update unavailability period
app.post('/update-unavailability', async (req, res) => {
  const { doctorId, unavailableUntil } = req.body;

  if (!doctorId) {
    return res.status(400).json({ message: 'Missing doctorId' });
  }

  try {
    await sql.connect(config);

    // Create a new SQL request
    const request = new sql.Request();

    // Query to update unavailability period
    const query = `
      UPDATE Doctor
      SET Unavailable_until = @unavailableUntil
      WHERE DoctorID = @doctorId
    `;

    // Add parameters to the request
    request.input('doctorId', sql.NVarChar, doctorId); // Use sql.NVarChar for string-based IDs

    // Handle null value for unavailableUntil
    if (unavailableUntil === null) {
      request.input('unavailableUntil', sql.Null);
    } else {
      // Convert the date to UTC before storing it
      const utcDate = new Date(unavailableUntil).toISOString();
      request.input('unavailableUntil', sql.DateTime, utcDate);
    }

    // Execute the query
    await request.query(query);

    res.status(200).json({ message: 'Unavailability updated successfully' });
  } catch (err) {
    console.error('Error updating unavailability:', err);
    res.status(500).json({ message: 'Internal server error' });
  } finally {
    sql.close();
  }
});
// API to fetch unavailability period
app.get('/get-unavailability', async (req, res) => {
  const { doctorId } = req.query;

  if (!doctorId) {
    return res.status(400).json({ message: 'Missing doctorId' });
  }

  try {
    await sql.connect(config);

    // Create a new SQL request
    const request = new sql.Request();

    // Query to fetch unavailability period
    const query = `
      SELECT Unavailable_until
      FROM Doctor
      WHERE DoctorID = @doctorId
    `;

    // Add the parameter to the request
    request.input('doctorId', sql.NVarChar, doctorId);

    // Execute the query
    const result = await request.query(query);

    if (result.recordset.length === 0) {
      return res.status(404).json({ message: 'Doctor not found' });
    }

    const unavailableUntil = result.recordset[0].Unavailable_until;
    res.status(200).json({
      doctorId,
      unavailableUntil: unavailableUntil ? unavailableUntil.toISOString() : null, // Return in UTC format
    });
  } catch (err) {
    console.error('Error fetching unavailability:', err);
    res.status(500).json({ message: 'Internal server error' });
  } finally {
    sql.close();
  }
});
app.post('/validate-phone-number', async (req, res) => {
  const { userId, phoneNumber } = req.body;

  if (!userId || !phoneNumber) {
    return res.status(400).json({ message: 'Missing required fields' });
  }

  // Validate phone number length (12 digits)
  if (phoneNumber.length !== 12 || !/^\d+$/.test(phoneNumber)) {
    return res.status(400).json({ message: 'Phone number must be 12 digits' });
  }

  try {
    // Connect to the database
    await sql.connect(config);

    // Create a new SQL request
    const request = new sql.Request();

    // Check if the phone number matches the current one
    const query = `
      SELECT Contact_number
      FROM Users
      WHERE UserID = @userId
    `;

    // Add parameters to the request
    request.input('userId', sql.NVarChar, userId);

    // Execute the query
    const result = await request.query(query);

    if (result.recordset.length === 0) {
      return res.status(404).json({ message: 'User not found' });
    }

    const currentPhoneNumber = result.recordset[0].Contact_number;

    if (currentPhoneNumber !== phoneNumber) {
      return res.status(400).json({ message: 'Phone number does not match' });
    }

    res.status(200).json({ message: 'Phone number validated successfully' });
  } catch (err) {
    console.error('Error validating phone number:', err);
    res.status(500).json({ message: 'Internal server error' });
  } finally {
    // Close the database connection
    sql.close();
  }
});
app.post('/change-phone-number', async (req, res) => {
  const { userId, newPhoneNumber } = req.body;

  if (!userId || !newPhoneNumber) {
    return res.status(400).json({ message: 'Missing required fields' });
  }

  // Validate new phone number length (12 digits)
  if (newPhoneNumber.length !== 12 || !/^\d+$/.test(newPhoneNumber)) {
    return res.status(400).json({ message: 'New phone number must be 12 digits' });
  }

  try {
    // Connect to the database
    await sql.connect(config);

    // Create a new SQL request
    const request = new sql.Request();

    // Update the contact number
    const query = `
      UPDATE Users
      SET Contact_number = @newPhoneNumber
      WHERE UserID = @userId
    `;

    // Add parameters to the request
    request.input('userId', sql.NVarChar, userId);
    request.input('newPhoneNumber', sql.VarChar, newPhoneNumber);

    // Execute the query
    await request.query(query);

    res.status(200).json({ message: 'Phone number updated successfully' });
  } catch (err) {
    console.error('Error updating phone number:', err);
    res.status(500).json({ message: 'Internal server error' });
  } finally {
    // Close the database connection
    sql.close();
  }
});


app.get("/latestConsultationId", async (req, res) => {
  const { admission_no } = req.query;

  if (!admission_no) {
    return res.status(400).send({ error: "Admission_no parameter is required" });
  }

  try {
    let pool = await sql.connect(config);
    let query = `
      SELECT TOP 1 ConsultationID
      FROM [medoQRST].[dbo].[Consultation]
      WHERE Admission_no = @Admission_no
      ORDER BY Date DESC, Time DESC;
    `;

    let result = await pool.request()
      .input("Admission_no", sql.NVarChar, admission_no)
      .query(query);

    if (result.recordset.length === 0) {
      return res.status(404).send({ message: "No consultation found for the specified admission number" });
    }

    res.json(result.recordset[0]);
  } catch (error) {
    console.error("Error: ", error.message);
    res.status(500).send({ error: "An error occurred while fetching the latest consultation ID" });
  }
});

app.post('/updateConsultation', async (req, res) => {
  const { consultationId, status, denialReason, unavailableUntil } = req.body;

  if (!consultationId || !status) {
    return res.status(400).send({ error: 'Consultation ID and Status are required' });
  }

  try {
    let pool = await sql.connect(config);

    // Update Consultation Table
    let updateConsultationQuery = `
      UPDATE [medoQRST].[dbo].[Consultation]
      SET
        [Status] = @status,
        [Denial_Reason] = @denialReason
      WHERE [ConsultationID] = @consultationId
    `;

    await pool.request()
      .input('consultationId', sql.VarChar, consultationId)
      .input('status', sql.VarChar, status)
      .input('denialReason', sql.VarChar, denialReason || null)
      .query(updateConsultationQuery);

    // If status is 'Denied', update Doctor table
    if (status === 'Denied') {
      let getDoctorIdQuery = `
        SELECT [Consulting_Physician] AS DoctorID
        FROM [medoQRST].[dbo].[Consultation]
        WHERE [ConsultationID] = @consultationId
      `;

      let result = await pool.request()
        .input('consultationId', sql.VarChar, consultationId)
        .query(getDoctorIdQuery);

      if (result.recordset.length === 0 || !result.recordset[0].DoctorID) {
        return res.status(400).send({ error: 'Consulting Physician not found for this consultation' });
      }

      const doctorId = result.recordset[0].DoctorID;

      let updateDoctorQuery = `
        UPDATE [medoQRST].[dbo].[Doctor]
        SET
          [Unavailable_until] = @unavailableUntil
        WHERE [DoctorID] = @doctorId
      `;

      await pool.request()
        .input('doctorId', sql.VarChar, doctorId)
        .input('unavailableUntil', sql.DateTime, unavailableUntil ? new Date(unavailableUntil) : null)
        .query(updateDoctorQuery);
    }

    res.json({ message: 'Consultation updated successfully' });
  } catch (error) {
    console.error("Error: ", error.message);
    res.status(500).send({ error: "An error occurred while updating the consultation" });
  }
});

app.get("/doctorMessages/:doctorId/:admissionNo", async (req, res) => {
  try {
    let pool = await sql.connect(config);
    let doctorId = req.params.doctorId;
    let admissionNo = req.params.admissionNo;

    // Fetch consultation records, unavailability period for denied consultations, and department name
    let query = `
      SELECT
        C.[ConsultationID],
        C.[Admission_no],
        C.[Requesting_Physician],
        C.[Consulting_Physician],
        C.[Reason],
        C.[Status],
        C.[Denial_Reason],
        C.[Date],
        C.[Time],
        C.[Additional_Description],
        C.[Type_of_Comments],
        CASE
          WHEN C.[Status] = 'Denied' THEN D.[Unavailable_until]
          ELSE NULL
        END AS Unavailable_until,
        D.[Department_ID] AS ConsultingPhysicianDepartmentID,
        DP.[Department_name] AS ConsultingPhysicianDepartmentName
      FROM [medoQRST].[dbo].[Consultation] C
      LEFT JOIN [medoQRST].[dbo].[Doctor] D
        ON C.[Consulting_Physician] = D.[DoctorID]
      LEFT JOIN [medoQRST].[dbo].[Department] DP
        ON D.[Department_ID] = DP.[DepartmentID]
      WHERE C.[Requesting_Physician] = @doctorId
        AND C.[Admission_no] = @admissionNo;
    `;

    let result = await pool
      .request()
      .input("doctorId", sql.VarChar, doctorId)
      .input("admissionNo", sql.VarChar, admissionNo)
      .query(query);

    if (result.recordset.length === 0) {
      return res.status(404).send({ message: "No consultations found for this doctor and admission number" });
    }

    // Construct the response
    let response = result.recordset.map(record => ({
      ConsultationID: record.ConsultationID,
      AdmissionNo: record.Admission_no,
      RequestingPhysician: record.Requesting_Physician,
      ConsultingPhysician: record.Consulting_Physician,
      ConsultingPhysicianDepartmentID: record.ConsultingPhysicianDepartmentID,
      ConsultingPhysicianDepartmentName: record.ConsultingPhysicianDepartmentName, // Mapped department name
      Reason: record.Reason,
      Status: record.Status,
      DenialReason: record.Denial_Reason,
      Date: record.Date,
      Time: record.Time,
      AdditionalDescription: record.Additional_Description,
      TypeOfComments: record.Type_of_Comments,
      UnavailableUntil: record.Unavailable_until // Only populated if Status is "Denied"
    }));

    res.json(response);
  } catch (error) {
    console.error("Error:", error.message);
    console.error("Stack Trace:", error.stack);
    res.status(500).send({ error: "An error occurred while fetching data", details: error.message });
  }
});

app.get("/departmentsWithDoctors", async (req, res) => {
  try {
    let pool = await sql.connect(config);
    let query = `
      SELECT
          D.DepartmentID,
          D.Department_name,
          Doc.DoctorID,
          Doc.Specialization,
          Doc.Unavailable_until,
          U.Name AS DoctorName -- Fetch the doctor's name from the Users table
      FROM
          [medoQRST].[dbo].[Department] D
      LEFT JOIN
          [medoQRST].[dbo].[Doctor] Doc ON D.DepartmentID = Doc.Department_ID
      LEFT JOIN
          [medoQRST].[dbo].[Users] U ON Doc.DoctorID = U.UserID -- Join with Users table to get the doctor's name
      ORDER BY
          D.DepartmentID, Doc.DoctorID;
    `;

    let result = await pool.request().query(query);

    if (result.recordset.length === 0) {
      return res.status(404).send({ message: "No department or doctor data found" });
    }

    let departmentMap = {};

    result.recordset.forEach((row) => {
      let deptId = row.DepartmentID;
      if (!departmentMap[deptId]) {
        departmentMap[deptId] = {
          DepartmentID: row.DepartmentID,
          DepartmentName: row.Department_name,
          Doctors: [],
        };
      }

      if (row.DoctorID) {
        let isUnavailable = row.Unavailable_until && new Date(row.Unavailable_until) > new Date();
       
        let doctorInfo = {
          DoctorID: row.DoctorID,
          DoctorName: row.DoctorName, // Include the doctor's name
          Specialization: row.Specialization,
          Status: isUnavailable ? `Unavailable till ${new Date(row.Unavailable_until).toLocaleDateString()}` : "Available",
          Unavailable_until: row.Unavailable_until
        };

        departmentMap[deptId].Doctors.push(doctorInfo);
      }
    });

    let response = Object.values(departmentMap);
    res.json(response);
  } catch (error) {
    console.error("Error: ", error.message);
    res.status(500).send({ error: "An error occurred while fetching departments and doctors" });
  }
});
app.get("/consultations/:consultationId", async (req, res) => {
  try {
      let { consultationId } = req.params;
      let pool = await sql.connect(config);

      // Fetch consultation details along with Consulting_Physician
      let consultationQuery = `
          SELECT
              Admission_no,
              Requesting_Physician,
              Consulting_Physician,
              Reason,
              Date,
              Time,
              Additional_Description,
              Type_of_Comments,
              Status,
              Denial_Reason,
              ConsultationID
          FROM [medoQRST].[dbo].[Consultation]
          WHERE ConsultationID = @ConsultationID
          ORDER BY Date DESC;
      `;

      let consultationResult = await pool.request()
          .input("ConsultationID", sql.NVarChar, consultationId)
          .query(consultationQuery);

      if (consultationResult.recordset.length === 0) {
          return res.status(404).json({ message: "No consultations found" });
      }

      let consultation = consultationResult.recordset[0];
      let { Consulting_Physician, Admission_no } = consultation;

      // Fetch the department of the consulting doctor
      let doctorQuery = `
          SELECT Department_ID, Specialization
          FROM [medoQRST].[dbo].[Doctor]
          WHERE DoctorID = @Consulting_Physician;
      `;

      let doctorResult = await pool.request()
          .input("Consulting_Physician", sql.NVarChar, Consulting_Physician)
          .query(doctorQuery);

      let doctorInfo = doctorResult.recordset.length > 0 ? doctorResult.recordset[0] : null;
      let departmentId = doctorInfo ? doctorInfo.Department_ID : null;
      let specialization = doctorInfo ? doctorInfo.Specialization : null;

      // Fetch department name using Department_ID
      let departmentQuery = `
          SELECT Department_name
          FROM [medoQRST].[dbo].[Department]
          WHERE DepartmentID = @DepartmentID;
      `;

      let departmentResult = await pool.request()
          .input("DepartmentID", sql.Int, departmentId)
          .query(departmentQuery);

      let departmentName = departmentResult.recordset.length > 0 ? departmentResult.recordset[0].Department_name : null;
     
      // Fetch Bed_no and Ward_no from PatientDetails table
      let patientDetailsQuery = `
          SELECT Ward_no, Bed_no
          FROM [medoQRST].[dbo].[PatientDetails]
          WHERE Admission_no = @Admission_no;
      `;

      let patientDetailsResult = await pool.request()
          .input("Admission_no", sql.NVarChar, Admission_no)
          .query(patientDetailsQuery);

      let bedNo = patientDetailsResult.recordset.length > 0 ? patientDetailsResult.recordset[0].Bed_no : null;
      let wardNo = patientDetailsResult.recordset.length > 0 ? patientDetailsResult.recordset[0].Ward_no : null;

      // Fetch Contact Number if Consulting_Physician matches UserID
      let userQuery = `
          SELECT Contact_number
          FROM [medoQRST].[dbo].[Users]
          WHERE UserID = @Consulting_Physician;
      `;

      let userResult = await pool.request()
          .input("Consulting_Physician", sql.NVarChar, Consulting_Physician)
          .query(userQuery);

      let contactNumber = userResult.recordset.length > 0 ? userResult.recordset[0].Contact_number : null;

      // Combine results
      res.status(200).json({
          ...consultation,
          Consulting_Department_ID: departmentId,
          Consulting_Department_Name: departmentName,
          Consulting_Specialization: specialization,
          Bed_no: bedNo,
          Ward_no: wardNo,
          Contact_number: contactNumber // Only included if the match is found
      });

  } catch (error) {
      console.error("SQL Error:", error);
      res.status(500).json({ message: "Internal server error", error: error.message });
  }
});


app.put("/msg-update-consultation", async (req, res) => {
  try {
      const { consultationId, consultingPhysician } = req.body;

      if (!consultationId || !consultingPhysician) {
          return res.status(400).json({ message: "Consultation ID and Consulting Physician are required" });
      }

      let pool = await sql.connect(config);

      // 🔍 Check if the ConsultationID exists
      let consultationCheck = await pool.request()
          .input("ConsultationID", sql.NVarChar, consultationId)
          .query("SELECT ConsultationID FROM [medoQRST].[dbo].[Consultation] WHERE ConsultationID = @ConsultationID");

      if (consultationCheck.recordset.length === 0) {
          return res.status(404).json({ message: "No consultation found with the given ConsultationID" });
      }

      // 🔍 Check if the consulting physician exists in Users table
      let doctorCheck = await pool.request()
          .input("UserID", sql.NVarChar, consultingPhysician)
          .query("SELECT UserID, Contact_number FROM [medoQRST].[dbo].[Users] WHERE UserID = @UserID");

      if (doctorCheck.recordset.length === 0) {
          return res.status(400).json({ message: "Invalid doctor ID. No such user exists." });
      }

      let contactNumber = doctorCheck.recordset[0].Contact_number;

      // ✅ Update Consultation with Consulting Physician, Date, Time, Status, and Denial_Reason
      let query = `
          UPDATE [medoQRST].[dbo].[Consultation]
          SET
              Consulting_Physician = @ConsultingPhysician,
              Date = GETDATE(),
              Time = CONVERT(VARCHAR, GETDATE(), 108),
              Status = 'Pending',
              Denial_Reason = NULL
          WHERE ConsultationID = @ConsultationID;
      `;

      let result = await pool.request()
          .input("ConsultationID", sql.NVarChar, consultationId)
          .input("ConsultingPhysician", sql.NVarChar, consultingPhysician)
          .query(query);

      if (result.rowsAffected[0] === 0) {
          return res.status(404).json({ message: "No consultation updated" });
      }

      res.status(200).json({
          message: "Consultation updated successfully",
          contact_number: contactNumber
      });
  } catch (error) {
      console.error("SQL Error:", error);
      res.status(500).json({ message: "Internal server error", error: error.message });
  }
});
app.get("/doctor/:userId", async (req, res) => {
  try {
    let { userId } = req.params;
    let pool = await sql.connect(config);

    let query = `
      SELECT
          U.Name,
          U.Contact_number,
          U.Alternate_contact_number,
          D.Specialization,
          D.Unavailable_until,
          Dept.Department_name
      FROM
          [medoQRST].[dbo].[Users] U
      JOIN
          [medoQRST].[dbo].[Doctor] D ON U.UserID = D.DoctorID
      JOIN
          [medoQRST].[dbo].[Department] Dept ON D.Department_ID = Dept.DepartmentID
      WHERE
          U.UserID = @UserID
          AND U.Role = 'Doctor';
    `;

    let result = await pool.request()
      .input("UserID", sql.NVarChar, userId)
      .query(query);

    if (result.recordset.length === 0) {
      return res.status(404).json({ message: "Doctor not found" });
    }

    res.status(200).json(result.recordset[0]);
  } catch (error) {
    console.error("Error fetching doctor details:", error);
    res.status(500).json({ message: "Internal server error" });
  }
});

app.get("/departmentsWithDoctors", async (req, res) => {
  try {
    let pool = await sql.connect(config);
    let query = `
      SELECT
          D.DepartmentID,
          D.Department_name,
          Doc.DoctorID,
          Doc.Specialization
      FROM
          [medoQRST].[dbo].[Department] D
      LEFT JOIN
          [medoQRST].[dbo].[Doctor] Doc ON D.DepartmentID = Doc.Department_ID
      ORDER BY
          D.DepartmentID, Doc.DoctorID;
    `;

    let result = await pool.request().query(query);

    if (result.recordset.length === 0) {
      return res.status(404).send({ message: "No department or doctor data found" });
    }

    // Organizing data in a structured way
    let departmentMap = {};

    result.recordset.forEach((row) => {
      let deptId = row.DepartmentID;
      if (!departmentMap[deptId]) {
        departmentMap[deptId] = {
          DepartmentID: row.DepartmentID,
          DepartmentName: row.Department_name,
          Doctors: [],
        };
      }
      if (row.DoctorID) {
        departmentMap[deptId].Doctors.push({
          DoctorID: row.DoctorID,
          Specialization: row.Specialization,
        });
      }
    });

    let response = Object.values(departmentMap); // Convert object to array
    res.json(response);
  } catch (error) {
    console.error("Error: ", error.message);
    res.status(500).send({ error: "An error occurred while fetching departments and doctors" });
  }
});


// Middleware to parse JSON bodies
app.use(express.json());

app.post("/insertProgress", async (req, res) => {
  // Log the incoming request body for debugging
  console.log("Request body:", req.body);

  // Ensure the required fields are present in the request body
  const { Admission_no, Progress_Date, Notes, Reported_By } = req.body;

  if (!Admission_no || !Notes || !Reported_By) {
    return res.status(400).send({ error: "Admission_no, Notes, and Reported_By are required" });
  }

  try {
    // Connect to the SQL database
    let pool = await sql.connect(config);

    // Insert the progress note into the database
    await pool.request()
      .input("Admission_no", sql.NVarChar, Admission_no)
      .input("Progress_Date", sql.DateTime, Progress_Date)
      .input("Notes", sql.NVarChar, Notes)
      .input("Reported_By", sql.NVarChar, Reported_By) // Add Reported_By field
      .query(`
        INSERT INTO [medoQRST].[dbo].[Progress]
        ([Admission_no], [Progress_Date], [Notes], [Reported_By])
        VALUES (@Admission_no, @Progress_Date, @Notes, @Reported_By)
      `);

    // Respond with success message
    res.status(200).send({ message: "Progress note added successfully." });
  } catch (error) {
    // Log the error and send a failure response
    console.error("Error inserting progress note:", error.message);
    res.status(500).send({ error: "Error inserting progress note." });
  }
});
app.post("/loginDoctor", async (req, res) => {
  const { userId, password } = req.body;

  try {
    let pool = await sql.connect(config);
    let result = await pool.request()
      .input('userId', sql.VarChar, userId)
      .query(`
        SELECT L.UserID, L.Password, U.Role
        FROM [medoQRST].[dbo].[Login] L
        JOIN [medoQRST].[dbo].[Users] U ON L.UserID = U.UserID
        WHERE L.UserID = @userId AND U.Role = 'Doctor'
      `);

    if (result.recordset.length === 0) {
      return res.status(404).json({ success: false, message: "Doctor not found" });
    }

    const user = result.recordset[0];
    const isMatch = await bcrypt.compare(password, user.Password);

    if (!isMatch) {
      return res.status(401).json({ success: false, message: "Invalid credentials" });
    }

    res.json({
      success: true,
      userID: user.UserID,
      role: user.Role
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

app.post("/loginNurse", async (req, res) => {
  const { userId, password } = req.body;

  try {
    let pool = await sql.connect(config);
    let result = await pool.request()
      .input('userId', sql.VarChar, userId)
      .query(`
        SELECT L.UserID, L.Password, U.Role
        FROM [medoQRST].[dbo].[Login] L
        JOIN [medoQRST].[dbo].[Users] U ON L.UserID = U.UserID
        WHERE L.UserID = @userId AND U.Role = 'Nurse'
      `);

    if (result.recordset.length === 0) {
      return res.status(404).json({ success: false, message: "Nurse not found" });
    }

    const user = result.recordset[0];
    const isMatch = await bcrypt.compare(password, user.Password);

    if (!isMatch) {
      return res.status(401).json({ success: false, message: "Invalid credentials" });
    }

    res.json({
      success: true,
      userID: user.UserID,
      role: user.Role
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
});

function convertToLocalTime(dateTimeString) {
  if (!dateTimeString) return null;

  const date = new Date(dateTimeString);
  const offset = date.getTimezoneOffset() * 60000; // Convert offset to milliseconds
  return new Date(date - offset); // Adjust to local time
}

app.get("/insertVitals", async (req, res) => {
 
  const vital = {
    Admission_no: req.query.Admission_no,
    Recorded_at: convertToLocalTime(req.query.Recorded_at),
    Blood_pressure: req.query.Blood_pressure,
    Respiration_rate: parseInt(req.query.Respiration_rate),
    Pulse_rate: parseInt(req.query.Pulse_rate),
    Oxygen_saturation: parseFloat(req.query.Oxygen_saturation),
    Temperature: parseFloat(req.query.Temperature),
    Random_blood_sugar: parseFloat(req.query.Random_blood_sugar),
  };

  try {
    let pool = await sql.connect(config);

    await pool.request()
      .input("Admission_no", sql.NVarChar, vital.Admission_no)
      .input("Recorded_at", sql.DateTime, vital.Recorded_at)
      .input("Blood_pressure", sql.NVarChar(50), vital.Blood_pressure)
      .input("Respiration_rate", sql.Int, vital.Respiration_rate)
      .input("Pulse_rate", sql.Int, vital.Pulse_rate)
      .input("Oxygen_saturation", sql.Float, vital.Oxygen_saturation)
      .input("Temperature", sql.Float, vital.Temperature)
      .input("Random_blood_sugar", sql.Float, vital.Random_blood_sugar)
      .query(`
        INSERT INTO [medoQRST].[dbo].[Vitals]
        ([Admission_no], [Recorded_at], [Blood_pressure], [Respiration_rate], [Pulse_rate], [Oxygen_saturation], [Temperature], [Random_blood_sugar])
        VALUES
        (@Admission_no, @Recorded_at, @Blood_pressure, @Respiration_rate, @Pulse_rate, @Oxygen_saturation, @Temperature, @Random_blood_sugar)
      `);

    console.log("Vitals data inserted successfully.");
    res.status(200).send({ message: "Vitals data inserted successfully." });
  } catch (error) {
    console.error("Error inserting vitals data:", error.message);
    res.status(500).send({ error: "Error inserting vitals data." });
  }
});app.post("/editDrugSheet", async (req, res) => {
  const now = new Date();
  const offset = now.getTimezoneOffset() * 60000;
  const localDate = new Date(now - offset);

  // Process input - convert empty strings to null
  const processField = (value) => {
    return (value && value.trim() !== '') ? value.trim() : null;
  };

  const drugInsert = {
    Admission_no: req.body.Admission_no,
    Commercial_name: processField(req.body.Commercial_name),
    Generic_name: processField(req.body.Generic_name),
    Strength: processField(req.body.Strength),
    Dosage: processField(req.body.Dosage),
    Monitored_By: processField(req.body.Monitored_By),
    Shift: processField(req.body.Shift),
    MedicationDate: localDate.toISOString().split("T")[0],
    MedicationTime: localDate.toISOString().split("T")[1].split(".")[0],
  };

  // Validate required fields
  if (!drugInsert.Admission_no || !drugInsert.Commercial_name || !drugInsert.Dosage || !drugInsert.Monitored_By || !drugInsert.Shift) {
    return res.status(400).send({ error: "Required fields (Commercial_name, Dosage, Monitored_By, Shift) are missing" });
  }

  try {
    let pool = await sql.connect(config);

    // Check if Admission_no exists
    let admissionCheck = await pool.request()
      .input("Admission_no", sql.NVarChar(50), drugInsert.Admission_no)
      .query(`
        SELECT 1 FROM [medoQRST].[dbo].[PatientDetails] WHERE Admission_no = @Admission_no;
      `);

    if (admissionCheck.recordset.length === 0) {
      return res.status(404).send({ error: `Admission number ${drugInsert.Admission_no} does not exist` });
    }

    // Dynamic drug lookup based on provided fields
    let drugQuery = `
      SELECT DrugID FROM [medoQRST].[dbo].[Drug]
      WHERE Commercial_name = @Commercial_name
    `;
   
    const drugRequest = pool.request()
      .input("Commercial_name", sql.NVarChar(255), drugInsert.Commercial_name);

    if (drugInsert.Generic_name !== null) {
      drugQuery += ` AND Generic_name = @Generic_name`;
      drugRequest.input("Generic_name", sql.NVarChar(255), drugInsert.Generic_name);
    } else {
      drugQuery += ` AND Generic_name IS NULL`;
    }

    if (drugInsert.Strength !== null) {
      drugQuery += ` AND Strength = @Strength`;
      drugRequest.input("Strength", sql.NVarChar(100), drugInsert.Strength);
    } else {
      drugQuery += ` AND Strength IS NULL`;
    }

    let drugResult = await drugRequest.query(drugQuery);

    let drugID;
    if (drugResult.recordset.length > 0) {
      drugID = drugResult.recordset[0].DrugID;
    } else {
      // Get new DrugID
      let maxDrugIDResult = await pool.request().query(`
        SELECT MAX(DrugID) AS MaxDrugID FROM [medoQRST].[dbo].[Drug];
      `);

      drugID = (maxDrugIDResult.recordset[0].MaxDrugID || 0) + 1;

      // Dynamic drug insertion based on provided fields
      let insertFields = ['DrugID', 'Commercial_name'];
      let insertValues = ['@DrugID', '@Commercial_name'];
     
      const insertRequest = pool.request()
        .input("DrugID", sql.Int, drugID)
        .input("Commercial_name", sql.NVarChar(255), drugInsert.Commercial_name);

      if (drugInsert.Generic_name !== null) {
        insertFields.push('Generic_name');
        insertValues.push('@Generic_name');
        insertRequest.input("Generic_name", sql.NVarChar(255), drugInsert.Generic_name);
      }

      if (drugInsert.Strength !== null) {
        insertFields.push('Strength');
        insertValues.push('@Strength');
        insertRequest.input("Strength", sql.NVarChar(100), drugInsert.Strength);
      }

      await insertRequest.query(`
        INSERT INTO [medoQRST].[dbo].[Drug] (${insertFields.join(', ')})
        VALUES (${insertValues.join(', ')});
      `);
    }

    // Insert into MedicationRecord
    await pool.request()
      .input("Admission_no", sql.NVarChar(50), drugInsert.Admission_no)
      .input("Drug_ID", sql.Int, drugID)
      .input("Dosage", sql.NVarChar(100), drugInsert.Dosage)
      .input("Monitored_By", sql.NVarChar(255), drugInsert.Monitored_By)
      .input("Shift", sql.NVarChar(50), drugInsert.Shift)
      .input("MedicationDate", sql.Date, drugInsert.MedicationDate)
      .input("MedicationTime", sql.Time, drugInsert.MedicationTime)
      .query(`
        INSERT INTO [medoQRST].[dbo].[MedicationRecord]
        (Admission_no, Drug_ID, Dosage, Monitored_By, Shift, Date, Time)
        VALUES (@Admission_no, @Drug_ID, @Dosage, @Monitored_By, @Shift, @MedicationDate, @MedicationTime);
      `);

    res.status(200).send({
      message: "Drug and medication record inserted successfully",
      data: {
        drugID,
        commercialName: drugInsert.Commercial_name,
        genericName: drugInsert.Generic_name,
        strength: drugInsert.Strength,
        dosage: drugInsert.Dosage
      }
    });
  } catch (error) {
    console.error("Error in /editDrugSheet:", error);
    res.status(500).send({
      error: "Failed to process drug sheet",
      details: error.message
    });
  }
});
app.post("/insertPrescription", async (req, res) => {
  const now = new Date();
  const offset = now.getTimezoneOffset() * 60000;
  const localDate = new Date(now - offset);

  const prescriptionData = {
    Admission_no: req.body.Admission_no?.trim(),
    Commercial_name: req.body.Commercial_name?.trim().toLowerCase(),
    Generic_name: req.body.Generic_name?.trim().toLowerCase(),
    Strength: req.body.Strength?.trim().toLowerCase(),
    Dosage: req.body.Dosage?.trim(),
    Prescribed_by: req.body.Prescribed_by?.trim(),
    PrescriptionDate: localDate.toISOString().split("T")[0],
    PrescriptionTime: localDate.toISOString().split("T")[1].split(".")[0],
  };

  // Validate required fields
  if (!prescriptionData.Admission_no || !prescriptionData.Commercial_name) {
    return res.status(400).send({
      error: "Missing required fields",
      details: !prescriptionData.Admission_no ? "Admission_no is required" : "Commercial_name is required"
    });
  }

  let pool;
  let transaction;

  try {
    pool = await sql.connect(config);
    transaction = new sql.Transaction(pool);
    await transaction.begin();

    // 1. Check if Admission_no exists
    const admissionCheck = await new sql.Request(transaction)
      .input("Admission_no", sql.NVarChar(50), prescriptionData.Admission_no)
      .query(`
        SELECT 1 FROM [medoQRST].[dbo].[PatientDetails]
        WHERE Admission_no = @Admission_no;
      `);

    if (admissionCheck.recordset.length === 0) {
      throw new Error(`Admission number ${prescriptionData.Admission_no} does not exist`);
    }

    // 2. Check if drug exists or insert new drug
    let drugID;
   
    // Build the WHERE clause dynamically
    let whereClause = `WHERE LTRIM(RTRIM(LOWER(Commercial_name))) = @Commercial_name`;
    const drugRequest = new sql.Request(transaction)
      .input("Commercial_name", sql.NVarChar(255), prescriptionData.Commercial_name);

    if (prescriptionData.Generic_name) {
      whereClause += ` AND LTRIM(RTRIM(LOWER(Generic_name))) = @Generic_name`;
      drugRequest.input("Generic_name", sql.NVarChar(255), prescriptionData.Generic_name);
    } else {
      whereClause += ` AND Generic_name IS NULL`;
    }

    if (prescriptionData.Strength) {
      whereClause += ` AND LTRIM(RTRIM(LOWER(Strength))) = @Strength`;
      drugRequest.input("Strength", sql.NVarChar(100), prescriptionData.Strength);
    } else {
      whereClause += ` AND Strength IS NULL`;
    }

    // First try to find existing drug
    const drugResult = await drugRequest.query(`
      SELECT DrugID FROM [medoQRST].[dbo].[Drug]
      ${whereClause};
    `);

    if (drugResult.recordset.length > 0) {
      drugID = drugResult.recordset[0].DrugID;
    } else {
      // Insert new drug (without OUTPUT clause due to trigger restriction)
      let insertColumns = `(Commercial_name`;
      let insertValues = `(@Commercial_name`;
     
      if (prescriptionData.Generic_name) {
        insertColumns += `, Generic_name`;
        insertValues += `, @Generic_name`;
      }
      if (prescriptionData.Strength) {
        insertColumns += `, Strength`;
        insertValues += `, @Strength`;
      }
     
      insertColumns += `)`;
      insertValues += `)`;
     
      await drugRequest.query(`
        INSERT INTO [medoQRST].[dbo].[Drug] ${insertColumns}
        VALUES ${insertValues};
      `);

      // Now get the ID we just inserted
      const newDrugResult = await drugRequest.query(`
        SELECT DrugID FROM [medoQRST].[dbo].[Drug]
        ${whereClause};
      `);

      if (newDrugResult.recordset.length > 0) {
        drugID = newDrugResult.recordset[0].DrugID;
      } else {
        throw new Error("Failed to retrieve DrugID after insertion");
      }
    }

    // 3. Check for existing prescription
    const prescriptionExists = await new sql.Request(transaction)
      .input("Admission_no", sql.NVarChar(50), prescriptionData.Admission_no)
      .input("Drug_ID", sql.Int, drugID)
      .query(`
        SELECT 1 FROM [medoQRST].[dbo].[Prescription]
        WHERE Admission_no = @Admission_no AND Drug_ID = @Drug_ID;
      `);

    if (prescriptionExists.recordset.length === 0) {
      // 4. Insert only if not exists
      await new sql.Request(transaction)
        .input("Admission_no", sql.NVarChar(50), prescriptionData.Admission_no)
        .input("Drug_ID", sql.Int, drugID)
        .input("Prescribed_by", sql.NVarChar(255), prescriptionData.Prescribed_by)
        .input("Dosage", sql.NVarChar(100), prescriptionData.Dosage)
        .query(`
          INSERT INTO [medoQRST].[dbo].[Prescription]
            (Admission_no, Drug_ID, Prescribed_by, Dosage)
          VALUES
            (@Admission_no, @Drug_ID, @Prescribed_by, @Dosage);
        `);
    }

    await transaction.commit();

    res.status(200).send({
      message: "Prescription handled successfully",
      drugID: drugID,
      inserted: prescriptionExists.recordset.length === 0
    });

  } catch (error) {
    if (transaction) await transaction.rollback();
    console.error("Error:", error.message);
    res.status(500).send({
      error: error.message,
      details: error.stack
    });
  } finally {
    if (pool) await pool.close();
  }
});
// API to invalidate a prescription (soft delete)
app.put('/invalidate-prescription/:recordId', async (req, res) => {
  const { recordId } = req.params;

  if (!recordId) {
    return res.status(400).json({ success: false, message: "Record ID is required" });
  }

  try {
    await sql.connect(config);
   
    // Update only the Medication_Status to 'invalid'
    const result = await sql.query`
      UPDATE [medoQRST].[dbo].[Prescription]
      SET Medication_Status = 'invalid'
      WHERE Record_ID = ${recordId}
    `;

    if (result.rowsAffected[0] > 0) {
      res.status(200).json({ success: true, message: "Prescription marked as invalid" });
    } else {
      res.status(404).json({ success: false, message: "Prescription not found" });
    }
  } catch (error) {
    console.error("Error invalidating prescription:", error);
    res.status(500).json({ success: false, message: "Error invalidating prescription" });
  } finally {
    sql.close();
  }
});
app.get('/prescriptions/:admissionNo', async (req, res) => {
  const { admissionNo } = req.params;

  try {
    await sql.connect(config);

    // Query for valid prescriptions (status not 'invalid')
    const validQuery = `
      SELECT
        p.Record_ID,
        p.Admission_no,
        p.Drug_ID,
        d.Commercial_name,
        d.Generic_name,
        d.Strength,
        p.Prescribed_by,
        u.Name AS PrescribedByName,
        p.Dosage,
        p.Medication_Status
      FROM [medoQRST].[dbo].[Prescription] p
      JOIN [medoQRST].[dbo].[Drug] d ON p.Drug_ID = d.DrugID
      LEFT JOIN [medoQRST].[dbo].[Users] u ON p.Prescribed_by = u.UserID
      WHERE p.Admission_no = '${admissionNo}'
      AND (LOWER(LTRIM(RTRIM(p.Medication_Status))) != 'invalid' OR p.Medication_Status IS NULL)
      ORDER BY p.Record_ID DESC
    `;

    // Query for invalid prescriptions (status = 'invalid')
    const invalidQuery = `
      SELECT
        p.Record_ID,
        p.Admission_no,
        p.Drug_ID,
        d.Commercial_name,
        d.Generic_name,
        d.Strength,
        p.Prescribed_by,
        u.Name AS PrescribedByName,
        p.Dosage,
        p.Medication_Status
      FROM [medoQRST].[dbo].[Prescription] p
      JOIN [medoQRST].[dbo].[Drug] d ON p.Drug_ID = d.DrugID
      LEFT JOIN [medoQRST].[dbo].[Users] u ON p.Prescribed_by = u.UserID
      WHERE p.Admission_no = '${admissionNo}'
      AND LOWER(LTRIM(RTRIM(p.Medication_Status))) = 'invalid'
      ORDER BY p.Record_ID DESC
    `;

    const validResult = await sql.query(validQuery);
    const invalidResult = await sql.query(invalidQuery);

    res.status(200).json({
      success: true,
      currentPrescriptions: validResult.recordset,
      pastPrescriptions: invalidResult.recordset
    });
  } catch (error) {
    console.error("Error fetching prescriptions:", error);
    res.status(500).json({ success: false, message: "Error fetching prescriptions" });
  } finally {
    sql.close();
  }
});

app.get("/insertConsultation", async (req, res) => {
  const consultation = {
    Admission_no: req.query.Admission_no,
    Requesting_Physician: req.query.Requesting_Physician,
    Consulting_Physician: req.query.Consulting_Physician,
    Reason: req.query.Reason,
    Date: new Date(req.query.Date), // Ensure the date is in a valid format
    Time: req.query.Time, // Time can be a string or parsed as needed
    Additional_Description: req.query.Additional_Description,
    Type_of_Comments: req.query.Type_of_Comments,
  };

  try {
    let pool = await sql.connect(config);

    await pool.request()
      .input("Admission_no", sql.NVarChar, consultation.Admission_no)
      .input("Requesting_Physician", sql.NVarChar, consultation.Requesting_Physician)
      .input("Consulting_Physician", sql.NVarChar, consultation.Consulting_Physician)
      .input("Reason", sql.NVarChar, consultation.Reason)
      .input("Date", sql.Date, consultation.Date)
      .input("Time", sql.NVarChar, consultation.Time)
      .input("Additional_Description", sql.NVarChar, consultation.Additional_Description)
      .input("Type_of_Comments", sql.NVarChar, consultation.Type_of_Comments)
      .query(`
        INSERT INTO [medoQRST].[dbo].[Consultation]
        ([Admission_no], [Requesting_Physician], [Consulting_Physician], [Reason], [Date], [Time], [Additional_Description], [Type_of_Comments])
        VALUES
        (@Admission_no, @Requesting_Physician, @Consulting_Physician, @Reason, @Date, @Time, @Additional_Description, @Type_of_Comments)
      `);

    console.log("Consultation data inserted successfully.");
    res.status(200).send({ message: "Consultation data inserted successfully." });
  } catch (error) {
    console.error("Error inserting consultation data:", error.message);
    res.status(500).send({ error: "Error inserting consultation data." });
  }
});


app.post('/getUserEmail', async (req, res) => {
  const { userId } = req.body;

  if (!userId) {
    return res.status(400).send({ error: 'User ID is required' });
  }

  let pool = null;  // Initialize pool

  try {
    pool = await sql.connect(config);
    let email = null;

    // First check Doctor table
    let doctorQuery = `
      SELECT Email
      FROM [medoQRST].[dbo].[Doctor]
      WHERE DoctorID = @userId
    `;

    let doctorResult = await pool.request()
      .input('userId', sql.VarChar, userId)
      .query(doctorQuery);

    if (doctorResult.recordset.length > 0) {
      email = doctorResult.recordset[0].Email;
    } else {
      // If not found in Doctor table, check Nurse table
      let nurseQuery = `
        SELECT Email
        FROM [medoQRST].[dbo].[Nurse]
        WHERE NurseID = @userId
      `;

      let nurseResult = await pool.request()
        .input('userId', sql.VarChar, userId)
        .query(nurseQuery);

      if (nurseResult.recordset.length > 0) {
        email = nurseResult.recordset[0].Email;
      }
    }

    if (!email) {
      return res.status(404).send({ error: 'User not found in Doctor or Nurse tables' });
    }

    // Trim the email before sending it in the response
    res.json({ Email: email.trim() });

  } catch (error) {
    console.error("Error: ", error.message);
    res.status(500).send({ error: "An error occurred while fetching user email" });
  } finally {
    // Close the SQL connection if it was successfully created
    if (pool) {
      await pool.close();
    }
  }
});



app.post('/nurse/validate-email', async (req, res) => {
  const { userId, oldEmail } = req.body;

  try {
    await sql.connect(config);
    const result = await sql.query`
      SELECT Email FROM Nurse WHERE NurseID = ${userId}
    `;

    if (result.recordset.length > 0 && result.recordset[0].Email === oldEmail) {
      res.status(200).json({ success: true });
    } else {
      res.status(400).json({ success: false, message: 'Old email does not match' });
    }
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

// 🔹 Send Verification Email for Nurse
app.post('/nurse/send-verification-email', async (req, res) => {
  const { newEmail } = req.body;

  try {
    const otp = Math.floor(100000 + Math.random() * 900000).toString(); // Generate 6-digit OTP

    const mailOptions = {
      from: 'medoqrst@gmail.com',
      to: newEmail,
      subject: '🔐 Verify Your Email - OTP Inside!',
      html: `
        <html>
          <head>
            <style>
              body {
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                margin: 0;
                padding: 0;
                background-color: #f4f4f4;
                color: #333;
              }
              .email-container {
                max-width: 600px;
                margin: 20px auto;
                background: #ffffff;
                border-radius: 12px;
                overflow: hidden;
                box-shadow: 0 5px 15px rgba(0, 0, 0, 0.15);
              }
              .header {
                background: linear-gradient(135deg, #007BFF, #0056b3);
                color: #ffffff;
                padding: 25px;
                text-align: center;
              }
              .header h1 {
                margin: 0;
                font-size: 24px;
                font-weight: bold;
              }
              .content {
                padding: 30px;
                text-align: center;
              }
              .content p {
                font-size: 16px;
                margin-bottom: 15px;
                color: #444;
              }
              .otp-code {
                font-size: 28px;
                font-weight: bold;
                color: #D32F2F;
                background: #f0f0f0;
                padding: 15px 30px;
                border-radius: 8px;
                display: inline-block;
                margin: 20px 0;
                letter-spacing: 2px;
              }
              .alert {
                font-size: 16px;
                color: #ff5722;
                font-weight: bold;
                margin-top: 20px;
              }
              .footer {
                background: #f1f1f1;
                padding: 15px;
                text-align: center;
                font-size: 12px;
                color: #777;
              }
              .footer a {
                color: #007BFF;
                text-decoration: none;
              }
              .button {
                display: inline-block;
                padding: 12px 25px;
                font-size: 16px;
                font-weight: bold;
                color: #ffffff;
                background: #007BFF;
                border-radius: 6px;
                text-decoration: none;
                margin-top: 20px;
              }
            </style>
          </head>
          <body>
            <div class="email-container">
              <div class="header">
                <h1>🔐 Email Verification OTP</h1>
              </div>
              <div class="content">
                <p>Hello,</p>
                <p>Your One-Time Password (OTP) for email verification is:</p>
                <div class="otp-code">${otp}</div>
                <p>This OTP is valid for <strong>5 minutes</strong>. Please do not share it with anyone.</p>
                <p>If you did not request this, please ignore this email.</p>
                <p class="alert">⚠️ Need help? Contact our support team.</p>
                <a href="mailto:support@medoqr.com" class="button">Contact Support</a>
              </div>
              <div class="footer">
                <p>Thank you,<br><strong>From MEDOQRST Team</strong></p>
              </div>
            </div>
          </body>
        </html>
      `,
    };
   

    await transporter.sendMail(mailOptions);

    res.status(200).json({ success: true, otp });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});
app.post('/nurse/update-email', async (req, res) => {
  const { userId, newEmail } = req.body;

  try {
    // Establish SQL connection
    const pool = await sql.connect(config);
   
    // Check if the connection is active
    if (!pool.connected) {
      return res.status(500).json({ success: false, message: 'Database connection failed' });
    }

    await sql.query`
      UPDATE Nurse SET Email = ${newEmail} WHERE NurseID = ${userId}
    `;
   
    res.status(200).json({ success: true });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  } finally {
    sql.close(); // Close connection to avoid memory leaks
  }
});


// 🔹 Send OTP for Nurse Password Change
app.post("/nurse/send-otp", async (req, res) => {
  const { userId } = req.body;

  try {
    // Fetch nurse email from the database
    await sql.connect(config);
    const result = await sql.query`
      SELECT Email FROM [medoQRST].[dbo].[Nurse] WHERE NurseID = ${userId}
    `;

    if (result.recordset.length === 0) {
      return res.status(404).json({ success: false, message: "Nurse not found" });
    }

    const nurseEmail = result.recordset[0].Email.trim();
    const otp = Math.floor(100000 + Math.random() * 900000).toString(); // 6-digit OTP

    // Store OTP temporarily
    otpStorage[userId] = otp;

    const mailOptions = {
      from: "medoqrst@gmail.com",
      to: nurseEmail,
      subject: "🔐 Your One-Time Password (OTP)",
      html: `
        <html>
          <head>
            <style>
              body {
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                margin: 0;
                padding: 0;
                background-color: #f7f7f7;
                color: #333;
              }
              .email-container {
                max-width: 600px;
                margin: 20px auto;
                background: #ffffff;
                border-radius: 10px;
                overflow: hidden;
                box-shadow: 0 4px 10px rgba(0, 0, 0, 0.1);
              }
              .header {
                background: linear-gradient(135deg, #4CAF50, #45a049);
                color: #ffffff;
                padding: 20px;
                text-align: center;
              }
              .header h1 {
                margin: 0;
                font-size: 24px;
                font-weight: bold;
              }
              .content {
                padding: 30px;
                text-align: center;
              }
              .content h2 {
                font-size: 22px;
                color: #4CAF50;
                margin-bottom: 20px;
              }
              .otp-code {
                font-size: 28px;
                font-weight: bold;
                color: #D32F2F;
                background: #f0f0f0;
                padding: 15px;
                border-radius: 8px;
                margin: 20px 0;
                display: inline-block;
              }
              .footer {
                background: #f1f1f1;
                padding: 15px;
                text-align: center;
                font-size: 12px;
                color: #777;
              }
              .footer a {
                color: #4CAF50;
                text-decoration: none;
              }
            </style>
          </head>
          <body>
            <div class="email-container">
              <div class="header">
                <h1>🔐 OTP Verification</h1>
              </div>
              <div class="content">
                <h2>Hello,</h2>
                <p>You requested a One-Time Password (OTP) to reset your password.</p>
                <div class="otp-code">${otp}</div>
                <p>This OTP is valid for <strong>5 minutes</strong>. Please do not share it with anyone.</p>
                <p>If you did not request this, please ignore this email.</p>
              </div>
              <div class="footer">
                <p>Thank you,<br><strong>From MEDOQRST Team</strong></p>
              </div>
            </div>
          </body>
        </html>
      `,
    };
   

    await transporter.sendMail(mailOptions);

    res.status(200).json({ success: true, message: "OTP sent successfully" });
  } catch (err) {
    console.error("Error sending OTP:", err);
    res.status(500).json({ success: false, message: "Failed to send OTP" });
  }
});

// 🔹 Verify OTP for Nurse
app.post("/nurse/verify-otp", async (req, res) => {
  const { userId, otp } = req.body;

  if (!otpStorage[userId] || otpStorage[userId] !== otp) {
    return res.status(400).json({ success: false, message: "Invalid OTP" });
  }

  // Clear OTP after verification
  delete otpStorage[userId];
  res.status(200).json({ success: true, message: "OTP verified successfully" });
});
app.post("/nurse/update-password", async (req, res) => {
  const { userId, newPassword } = req.body;

  try {
    // Generate a salt
    const salt = await bcrypt.genSalt(10);
    // Hash the password
    const hashedPassword = await bcrypt.hash(newPassword, salt);

    // Connect to SQL Server
    await sql.connect(config);
   
    // Update password in database
    await sql.query`
      UPDATE [medoQRST].[dbo].[Login]
      SET Password = ${hashedPassword}  -- Store hashed password
      WHERE UserID = ${userId}
    `;

    res.status(200).json({ success: true, message: "Password updated successfully" });
  } catch (err) {
    console.error("Error updating password:", err);
    res.status(500).json({ success: false, message: "Failed to update password" });
  }
});

// 🔹 Validate Nurse's Phone Number
app.post('/nurse/validate-phone-number', async (req, res) => {
  const { userId, phoneNumber } = req.body;

  if (!userId || !phoneNumber) {
    return res.status(400).json({ message: 'Missing required fields' });
  }

  // Validate phone number length (12 digits)
  if (phoneNumber.length !== 12 || !/^\d+$/.test(phoneNumber)) {
    return res.status(400).json({ message: 'Phone number must be 12 digits' });
  }

  try {
    // Connect to the database
    await sql.connect(config);

    // Create a new SQL request
    const request = new sql.Request();

    // Check if the phone number matches the current one
    const query = `
      SELECT Contact_number
      FROM Users
      WHERE UserID = @userId AND Role = 'Nurse'
    `;

    // Add parameters to the request
    request.input('userId', sql.NVarChar, userId);

    // Execute the query
    const result = await request.query(query);

    if (result.recordset.length === 0) {
      return res.status(404).json({ message: 'Nurse not found' });
    }

    const currentPhoneNumber = result.recordset[0].Contact_number;

    if (currentPhoneNumber !== phoneNumber) {
      return res.status(400).json({ message: 'Phone number does not match' });
    }

    res.status(200).json({ message: 'Phone number validated successfully' });
  } catch (err) {
    console.error('Error validating phone number:', err);
    res.status(500).json({ message: 'Internal server error' });
  } finally {
    // Close the database connection
    sql.close();
  }
});

// 🔹 Change Nurse's Phone Number
app.post('/nurse/change-phone-number', async (req, res) => {
  const { userId, newPhoneNumber } = req.body;

  if (!userId || !newPhoneNumber) {
    return res.status(400).json({ message: 'Missing required fields' });
  }

  // Validate new phone number length (12 digits)
  if (newPhoneNumber.length !== 12 || !/^\d+$/.test(newPhoneNumber)) {
    return res.status(400).json({ message: 'New phone number must be 12 digits' });
  }

  try {
    // Connect to the database
    await sql.connect(config);

    // Create a new SQL request
    const request = new sql.Request();

    // Update the contact number
    const query = `
      UPDATE Users
      SET Contact_number = @newPhoneNumber
      WHERE UserID = @userId AND Role = 'Nurse'
    `;

    // Add parameters to the request
    request.input('userId', sql.NVarChar, userId);
    request.input('newPhoneNumber', sql.VarChar, newPhoneNumber);

    // Execute the query
    await request.query(query);

    res.status(200).json({ message: 'Phone number updated successfully' });
  } catch (err) {
    console.error('Error updating phone number:', err);
    res.status(500).json({ message: 'Internal server error' });
  } finally {
    // Close the database connection
    sql.close();
  }
});

// 🔹 Get Nurse's Current Email
app.post('/nurse/get-current-email', async (req, res) => {
  const { userId } = req.body;

  try {
    await sql.connect(config);
    const result = await sql.query`
      SELECT Email FROM Users WHERE UserID = ${userId} AND Role = 'Nurse'
    `;

    if (result.recordset.length === 0) {
      return res.status(404).json({ success: false, message: 'Nurse not found' });
    }

    const currentEmail = result.recordset[0].Email.trim();
    res.status(200).json({ success: true, email: currentEmail });
  } catch (err) {
    console.error('Error fetching current email:', err);
    res.status(500).json({ success: false, message: 'Internal server error' });
  } finally {
    sql.close();
  }
});

// 🔹 Send Email Change Notification for Nurse
app.post('/nurse/send-email-change-notification', async (req, res) => {
  const { currentEmail, newEmail } = req.body;

  try {
    const mailOptions = {
      from: 'medoqrst@gmail.com',
      to: currentEmail,
      subject: '🔔 Important: Email Address Updated Successfully!',
      html: `
        <html>
          <head>
            <style>
              body {
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                margin: 0;
                padding: 0;
                background-color: #f4f4f4;
                color: #333;
              }
              .email-container {
                max-width: 600px;
                margin: 20px auto;
                background: #ffffff;
                border-radius: 12px;
                overflow: hidden;
                box-shadow: 0 5px 15px rgba(0, 0, 0, 0.15);
              }
              .header {
                background: linear-gradient(135deg, #007BFF, #0056b3);
                color: #ffffff;
                padding: 25px;
                text-align: center;
              }
              .header h1 {
                margin: 0;
                font-size: 24px;
                font-weight: bold;
              }
              .content {
                padding: 30px;
                text-align: center;
              }
              .content p {
                font-size: 16px;
                margin-bottom: 15px;
                color: #444;
              }
              .alert {
                font-size: 16px;
                color: #D32F2F;
                font-weight: bold;
                margin-top: 20px;
              }
              .footer {
                background: #f1f1f1;
                padding: 15px;
                text-align: center;
                font-size: 12px;
                color: #777;
              }
              .footer a {
                color: #007BFF;
                text-decoration: none;
              }
              .button {
                display: inline-block;
                padding: 12px 25px;
                font-size: 16px;
                font-weight: bold;
                color: #ffffff;
                background: #D32F2F;
                border-radius: 6px;
                text-decoration: none;
                margin-top: 20px;
              }
            </style>
          </head>
          <body>
            <div class="email-container">
              <div class="header">
                <h1>🔔 Email Address Updated</h1>
              </div>
              <div class="content">
                <p>Hello,</p>
                <p>Your email address has been successfully updated to:</p>
                <p><strong>${newEmail}</strong></p>
                <p>If you made this change, no further action is required.</p>
                <p class="alert">⚠️ If you did not authorize this change, please contact support immediately!</p>
                <a href="mailto:support@medoqr.com" class="button">Contact Support</a>
                <p>Or call us at <strong>+92 123 4567890</strong></p>
              </div>
              <div class="footer">
                <p>Thank you,<br><strong>MEDOQRST Support Team</strong></p>
              </div>
            </div>
          </body>
        </html>
      `,
    };
   

    await transporter.sendMail(mailOptions);
    res.status(200).json({ success: true, message: 'Notification email sent successfully' });
  } catch (err) {
    console.error('Error sending notification email:', err);
    res.status(500).json({ success: false, message: 'Failed to send notification email' });
  }
});
app.post('/get-current-email', async (req, res) => {
  const { userId } = req.body;

  try {
    await sql.connect(config);
    const result = await sql.query`
      SELECT Email FROM Users WHERE UserID = ${userId}
    `;

    if (result.recordset.length === 0) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }

    const currentEmail = result.recordset[0].Email.trim();
    res.status(200).json({ success: true, email: currentEmail });
  } catch (err) {
    console.error('Error fetching current email:', err);
    res.status(500).json({ success: false, message: 'Internal server error' });
  } finally {
    sql.close();
  }
});

// Start the server
app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
});
