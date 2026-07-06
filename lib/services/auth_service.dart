import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user_model.dart';
import '../utils/logger.dart';

class AuthService extends ChangeNotifier {
  UserModel? _currentUser;
  static const String _userKey = 'user_data';

  UserModel? get currentUser => _currentUser;

  Future<bool> signUp(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      user.id = DateTime.now().millisecondsSinceEpoch.toString();
      user.isLoggedIn = true;
      user.lastLogin = DateTime.now();

      String userJson = jsonEncode(user.toJson());
      await prefs.setString(_userKey, userJson);

      _currentUser = user;
      notifyListeners();
      return true;
    } catch (e) {
      Logger.log('SignUp error: $e');
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? userJson = prefs.getString(_userKey);

      if (userJson != null) {
        Map<String, dynamic> userMap = jsonDecode(userJson);
        if (userMap['email'] == email) {
          _currentUser = UserModel.fromJson(userMap);
          _currentUser!.isLoggedIn = true;
          _currentUser!.lastLogin = DateTime.now();

          await prefs.setString(_userKey, jsonEncode(_currentUser!.toJson()));

          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      Logger.log('Login error: $e');
      return false;
    }
  }

  Future<bool> isLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? userJson = prefs.getString(_userKey);

      if (userJson != null) {
        Map<String, dynamic> userMap = jsonDecode(userJson);
        _currentUser = UserModel.fromJson(userMap);
        return _currentUser?.isLoggedIn ?? false;
      }
      return false;
    } catch (e) {
      Logger.log('isLoggedIn error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_currentUser != null) {
        _currentUser!.isLoggedIn = false;
        await prefs.setString(_userKey, jsonEncode(_currentUser!.toJson()));
      }
      _currentUser = null;
      notifyListeners();
    } catch (e) {
      Logger.log('Logout error: $e');
    }
  }
}
