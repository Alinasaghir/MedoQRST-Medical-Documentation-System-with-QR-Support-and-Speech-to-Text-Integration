var Db = require('./dboperations');
var Order = require('./order');
const dboperations = require('./dboperations');
const sql = require("mssql/msnodesqlv8");
var express = require('express');
var bodyParser = require('body-parser');
var cors = require('cors');
var app = express();
var router = express.Router();
var config = require('./dbconfig');
app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());
app.use(cors());
app.use('/api', router);
const moment = require('moment');


// Middleware to log the request
router.use((request, response, next) => {
    console.log('middleware');
    next();
});

// Get all orders
router.route('/orders').get((request, response) => {
    dboperations.getOrders().then(result => {
        response.json(result); // Return the whole result directly without accessing the first element
    }).catch(error => {
        response.status(500).json({ message: 'Error retrieving orders', error });
    });
});

// Get a single order by ID
router.route('/orders/:id').get((request, response) => {
    dboperations.getOrder(request.params.id).then(result => {
        if (result) {
            response.json(result); // Return the order directly
        } else {
            response.status(404).json({ message: 'Order not found' });
        }
    }).catch(error => {
        response.status(500).json({ message: 'Error retrieving order', error });
    });
});

// Add a new order
router.route('/orders').post((request, response) => {
    let order = { ...request.body }; // Ensure the order data matches the structure expected by addOrder

    dboperations.addOrder(order).then(result => {
        if (result.rowsAffected && result.rowsAffected[0] > 0) {
            response.status(201).json({ message: 'Order created successfully' });
        } else {
            response.status(200).json({ message: 'OK!' });
        }
    }).catch(error => {
        response.status(500).json({ message: 'Error adding order', error });
    });
});

// Delete an order by Bed_no and Ward_no
// Delete an order by Bed_no and Ward_no
router.route('/orders/:bedNo/:wardNo/:time/:date').delete((request, response) => {
    const bedNo = parseInt(request.params.bedNo);  // Ensure it's an integer
    const wardNo = request.params.wardNo.padStart(3, '0');  // Pad Ward_no to 3 digits (e.g., "002")
    const time = request.params.time;
    const date = request.params.date;

    dboperations.deleteMessage(bedNo, wardNo, time, date).then(result => {
        if (result.rowsAffected && result.rowsAffected[0] > 0) {
            response.status(200).json({ message: `Order with Bed_no: ${bedNo}, Ward_no: ${wardNo}, Time: ${time}, Date: ${date} deleted successfully.` });
        } else {
            response.status(404).json({ message: `No order found with Bed_no: ${bedNo}, Ward_no: ${wardNo}, Time: ${time}, Date: ${date}` });
        }
    }).catch(error => {
        response.status(500).json({ message: 'MESSAGE DELETED SUCCESSFULLY', error });
    });
});
app.put('/api/orders/:bedNo/:wardNo/:time/:date', async (req, res) => {
    try {
      const { bedNo, wardNo, time, date } = req.params;
      const { Update_notes, Last_updated_by } = req.body;
  
      // Get the current date and time
      const currentDateTime = moment().format('YYYY-MM-DD HH:mm:ss');
  
      // Fetch the Bed_no and Ward_no from the database (if necessary)
      const result = await sql.query`SELECT Bed_no, Ward_no FROM WardOverRegister WHERE Bed_no = ${bedNo} AND Ward_no = ${wardNo}`;
      if (result.recordset.length === 0) {
        return res.status(404).json({ error: 'Bed or Ward not found.' });
      }
      const { Bed_no, Ward_no } = result.recordset[0];
  
      // Construct the SQL query to update the message
      const updateQuery = `
        UPDATE WardOverRegister
        SET Update_notes = @Update_notes,
            Last_update_date = @Last_update_date,
            Last_update_time = @Last_update_time,
            Last_updated_by = @Last_updated_by
        WHERE Bed_no = @Bed_no AND Ward_no = @Ward_no AND Last_update_time = @Time AND Last_update_date = @Date;
    `;

      
  
      // Execute the SQL query
      const request = new sql.Request();
      request.input('Update_notes', sql.NVarChar, Update_notes);
      request.input('Last_update_date', sql.Date, currentDateTime.split(' ')[0]); // Only date
      request.input('Last_update_time', sql.Time, currentDateTime.split(' ')[1]); // Only time
      request.input('Last_updated_by', sql.NVarChar, Last_updated_by);
      request.input('Bed_no', sql.Int, Bed_no);
      request.input('Ward_no', sql.Int, Ward_no);
      request.input('Time', sql.Time, time);
      request.input('Date', sql.Date, date);
  
      await request.query(updateQuery);
  
      res.status(200).json({ message: 'Message updated successfully' });
    } catch (err) {
      console.error('Error occurred while updating message:', err);
      res.status(500).json({ error: 'Failed to update message. Please try again later.' });
    }
  });
  
  
router.get("/loginDoctor", async (req, res) => {
    try {
      let pool = await sql.connect(config);
  
      let query = `
      SELECT 
          L.[UserID],
          L.[Password],
          U.[Name],
          U.[Role]
      FROM 
          [medoQRST].[dbo].[Login] L
      JOIN 
          [medoQRST].[dbo].[Users] U ON L.UserID = U.UserID
      WHERE 
          U.Role = 'Doctor';
      `;
  
      let result = await pool.request().query(query);
  
      console.log("Fetched login data:", result.recordset); // Log all data to the console
  
      if (result.recordset.length === 0) {
        return res.status(404).send({ message: "No login data found" });
      }
  
      res.json(result.recordset);
    } catch (error) {
      console.error("Error: ", error.message);
      res.status(500).send({ error: "An error occurred while fetching login data" });
    }
  });


var port = process.env.PORT || 8090;
app.listen(port, () => {
    console.log('Order API is running at ' + port);
});
